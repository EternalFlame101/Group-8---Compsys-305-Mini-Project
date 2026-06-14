# Audio System — Bill of Materials & Wiring Reference (Living Document)

> **Status:** Post-submission continuation project. Goal: best possible loud + clear audio
> for university open day demo. Budget is flexible — upgrades welcome even if they
> overlap with existing parts.
>
> This document consolidates several earlier AI-assisted design passes (which disagreed
> with each other on some component values) into one canonical reference, cross-checked
> against the confirmed physical build. Items marked **[VERIFY]** need a DMM check against
> the breadboard — see Section 6.

---

## 1. Confirmed Physical Inventory (as of June 2026)

| Component | Qty | Part / Spec | Source |
|---|---|---|---|
| DAC0802LCN | 2 | 8-bit current-output DAC | Confirmed |
| TLC082 | 1 | Dual BiMOS op-amp | Confirmed |
| LM386N-1 | 1 | Audio power amp, gain ×20–200 | Confirmed |
| Speaker | 1 | 57mm, 8Ω — Jaycar AS3000 ("All Purpose Replacement Speaker") | Confirmed |
| Potentiometer | 1 | 10kΩ | Confirmed — Configuration A (signal divider, §5) |
| FPGA | 1 | Terasic DE0-CV, Cyclone V 5CEBA4F23C7 | Confirmed |
| SD Card | 1 | Custom raw-sector partition, sector 0+ = 44.1kHz 16-bit signed mono PCM | Confirmed |

---

## 2. Digital Interface (FPGA ↔ DACs)

This part is well-documented and consistent across all design passes — matches the working VHDL (`Audio_Playback.vhd`, `Top_Level.vhd`).

### High-Byte DAC (DAC0802 #1) — receives `dac_high`

| DAC0802 Pin | Signal | FPGA Connection |
|---|---|---|
| 5 (B1, MSB) | bit 7 | GPIO_0[19] |
| 6 (B2) | bit 6 | GPIO_0[18] |
| 7 (B3) | bit 5 | GPIO_0[17] |
| 8 (B4) | bit 4 | GPIO_0[16] |
| 9 (B5) | bit 3 | GPIO_0[15] |
| 10 (B6) | bit 2 | GPIO_0[14] |
| 11 (B7) | bit 1 | GPIO_0[13] |
| 12 (B8, LSB) | bit 0 | GPIO_0[12] |

### Low-Byte DAC (DAC0802 #2) — receives `dac_low`

| DAC0802 Pin | Signal | FPGA Connection |
|---|---|---|
| 5 (B1, MSB) | bit 7 | GPIO_0[11] |
| 6 (B2) | bit 6 | GPIO_0[10] |
| 7 (B3) | bit 5 | GPIO_0[9] |
| 8 (B4) | bit 4 | GPIO_0[8] |
| 9 (B5) | bit 3 | GPIO_0[7] |
| 10 (B6) | bit 2 | GPIO_0[6] |
| 11 (B7) | bit 1 | GPIO_0[5] |
| 12 (B8, LSB) | bit 0 | GPIO_0[4] |

**Debug mirror (GPIO_0[3:0]):** SPI signals mirrored for oscilloscope probing — SD_CLK, CS, MOSI, MISO. Unused pins GPIO_0[35:20] driven low / tri-stated.

**Byte-order note:** PCM is little-endian (low byte first in the stream). The VHDL state machine's "low_byte" register actually maps to `dac_high_reg` after MSB inversion — this is the signed→unsigned conversion, not a wiring error. Don't "fix" this if cross-referencing against a naive byte-order reading.

---

## 3. DAC0802 Analog-Side Wiring (per chip, both chips identical except IOUT routing)

| DAC0802 Pin | Name | Connect to |
|---|---|---|
| 1 (VLC) | — | GND rail |
| 2 (IOUT-bar) | — | GND rail (complement output, unused) |
| 3 (V−) | — | −5V rail |
| 4 (IOUT) | Current output | See §4 (TLC082 summing) |
| 13 (V+) | — | +5V rail + 0.1µF ceramic decoupling cap to GND, close to chip |
| 14 (VREF+) | — | **4.7kΩ** resistor to +5V rail — **confirmed value** |
| 15 (VREF−) | — | GND rail |
| 16 (COMP) | — | 10nF ceramic cap to −5V rail — frequency-compensation pin for the DAC's internal output amp (datasheet-recommended, prevents output ringing/instability). **Confirmed.** |

> **Note on VREF = 4.7kΩ:** This sets matched full-scale IOUT on both DACs (good —
> both bytes share the same current range, which is required for the byte-weighting
> math in §4 to work at all). The byte-weighting *ratio* itself is set by the
> summing-stage resistors (§4), which were measured as Rf_A=5kΩ / R_in=1.2MΩ,
> giving a ratio of 240 (6.7% error from ideal 256). See §4 and §7.4 for the
> one-resistor fix to bring this to 255.3 (0.26% error) using 4.7kΩ to match VREF.

---

## 4. TLC082 Summing Stage — **CONFIRMED VALUES (measured via DMM)**

| TLC082 Pin | Function | Connect to |
|---|---|---|
| 1 | Ch A output | Feedback resistor (**5kΩ confirmed**) to pin 2, AND **1.2MΩ (confirmed)** into pin 6 |
| 2 | Ch A −input | DAC IOUT input (one of the two DACs — see note below) + feedback resistor to pin 1 (5kΩ) |
| 3 | Ch A +input | GND |
| 4 | V− | −5V rail |
| 5 | Ch B +input | GND |
| 6 | Ch B −input | DAC IOUT input (the other DAC) directly, AND Ch A output (pin 1) via 1.2MΩ, AND feedback resistor to pin 7 (**4.7kΩ confirmed**) |
| 7 | Ch B output | 16-bit composite audio signal out → coupling cap (§5) |
| 8 | V+ | +5V rail + 0.1µF ceramic decoupling cap to GND, close to chip |

**Confirmed resistor values:**
- TLC082 pin1↔pin2 (Ch A feedback, "Rf_A") = **5kΩ** (hand-picked from a 5.1kΩ batch, verified 5kΩ exact via DMM)
- TLC082 pin1→pin6 ("R_in", couples Ch A's output into Ch B's summing junction) = **1.2MΩ** (exact)
- TLC082 pin6↔pin7 (Ch B feedback, "Rf_B") = **4.7kΩ**

> **Which DAC feeds which op-amp input:** The earlier doc assumed Ch A's pin2 takes
> the high-byte DAC directly. Given the ratio math below only works out sensibly
> with **R_in/Rf_A = 256** as the high:low weighting, the channel whose current path
> goes through *Rf_A then R_in into Ch B* is the one that ends up weighted by
> `Rf_A × Rf_B / R_in`, while the channel feeding pin6 directly is weighted by `Rf_B`
> alone. For the high byte to dominate by ~256×, **the high-byte DAC must be the one
> going into Ch A (pin2)**, consistent with the original §2 GPIO table. If playback
> sounds like mostly noise/static with no recognizable melody, swap which DAC feeds
> pin2 vs pin6 — that's the symptom of the bytes being weighted backwards.

**Summing math (as measured):**
```
Ratio = R_in / Rf_A = 1.2MΩ / 5kΩ = 240
Target ratio = 2^8 = 256
Error = 6.7%
```
This is in the audible-but-functional range — expect some "zipper" stepping noise
on quiet passages, but the song should still be clearly recognizable. See §7.4 for
the one-resistor fix to bring this to 0.26% error.

`Rf_B` (4.7kΩ) sets the overall output level/gain for the composite signal but does
**not** affect the high:low ratio — no need to touch it for ratio tuning.

---

## 5. Output Stage — Coupling, Volume, LM386, Speaker

### Coupling capacitor (TLC082 → LM386)
- 10µF electrolytic, **+** side toward TLC082 pin 7, **−** side toward LM386 pin 3.

### Volume potentiometer (10kΩ) — **CONFIRMED: Configuration A (signal-path divider)**

```
TLC082 pin 7 → 10µF cap (one leg) → pot LEFT leg
pot RIGHT leg → GND
pot WIPER (middle) → LM386 pin 3
```

A 10kΩ pot here acts as a simple voltage divider — turning it changes signal
amplitude directly into LM386 pin 3. This is the right call for a 10kΩ pot (the
LM386-gain-pin alternative wants ≤1.35kΩ and would have been awkward at 10kΩ).
**No change needed here.**

**Coupling cap polarity note:** you identified the "gold strip" side of the 10µF
cap (the lead toward the pot/LM386 side) as the negative terminal. Both sides of
this cap sit near 0V DC (TLC082 output is centered on the ±5V split supply with
no significant DC offset; the pot's left leg floats to ~0V through the pot body
to the grounded right leg), so DC stress across the cap is minimal either way —
this isn't a likely source of problems even if the marking is ambiguous. Worth a
quick double-check on the PCB layout (negative lead toward whichever side reads
closer to 0V/GND), but not urgent for the breadboard.

### LM386N-1

| Pin | Connect to |
|---|---|
| 1 (GAIN) | See pot config above |
| 2 (−IN) | GND |
| 3 (+IN) | From coupling cap (see above) |
| 4 (GND) | GND rail |
| 5 (OUTPUT) | Output coupling cap → speaker |
| 6 (VS) | +5V rail + 0.1µF ceramic decoupling cap to GND |
| 7 (BYPASS) | Leave open (unless Config A — then may be left open regardless) |
| 8 (GAIN) | See pot config above |

### Output coupling cap → Speaker
- **220µF electrolytic — confirmed.**
- + side toward LM386 pin 5, − side toward speaker terminal.

### Speaker
- Jaycar AS3000, 57mm, 8Ω. **This is rated for very low power (~0.5–1W typical for this product class)** — see §7, this is the #1 candidate for an open-day loudness upgrade.

---

## 6. Verification Checklist (use your DMM)

### 6.1 — Pot wiring — ✅ DONE
Confirmed Configuration A. See §5.

### 6.2 — Summing stage resistors — ✅ DONE
Confirmed: Rf_A (pin1↔pin2) = 5kΩ, R_in (pin1→pin6) = 1.2MΩ, Rf_B (pin6↔pin7) = 4.7kΩ. See §4.

### 6.3 — COMP cap (10nF) — ✅ DONE
10nF ceramic, confirmed on both DACs.

### 6.4 — Output coupling cap — ✅ DONE
220µF electrolytic, confirmed.

---

## 7. Open-Day Upgrade Path (Loud + Clear, Budget Flexible)

Priority order for audible improvement, roughly cheapest/easiest first:

### 7.1 — Speaker upgrade (highest impact for "loud") — sourced
The AS3000 is a small general-purpose replacement speaker, not a high-output driver. For a noisy open-day hall:
- Get a **matched pair of 3" 8Ω full-range drivers** for stereo: [2Pcs 3 Inch Portable Full Range Speaker 78mm 8Ω](https://www.aliexpress.com/item/1005005430483749.html)
- Mount each in a small sealed enclosure (a small box — sealed or with a port cut out) — an unenclosed small driver loses most of its bass and sounds thin/quiet by comparison. This is often a bigger jump in perceived loudness than the amp itself.

### 7.2 — Amplifier upgrade: PAM8403 module — sourced
- [PAM8403 Mini Board 2x3W 2-Channel Stereo Digital Audio Amplifier, USB 5V power](https://www.aliexpress.com/i/3256808825664896.html?gatewayAdapt=4itemAdapt) — one chip, already stereo (2 channels), with volume pot.
- Replaces LM386N-1 + the 220µF output cap + the volume pot stage.
- TLC082/TLC084 summing stage(s) stay exactly as-is — PAM8403 input is still analog, fed from the op-amp's output via the same 10µF coupling cap (per channel).
- Differential speaker output — no output coupling cap needed, slightly cleaner low end.
- Runs natively on 5V via USB → ties directly into the power plan in §7.5 (separate USB supply from the analog ±5V rails = better noise isolation, not just convenience).

### 7.3 — Stereo expansion (if you want it for the open day "wow" factor) — sourced
- Duplicate the DAC0802 + summing stage for a second channel, feed PAM8403's second input (it's stereo natively), use GPIO_1 for the second channel's 16-bit bus.
- Requires: 2× more DAC0802 (4 total), VHDL changes to `Audio_Playback.vhd` for stereo sample reads, and re-encoding the SD card audio as stereo interleaved PCM.
- Op-amp consolidation: replace your single TLC082 (dual) with **one TLC084** (TI BiMOS quad, same family, drop-in for 2× TLC082's worth of op-amps — handles both channels' summing stages in one 14-DIP chip). [TLC084 product page](https://www.ti.com/product/TLC084) — if hard to source quickly, the classic **TL084** (JFET quad, pin-compatible 14-DIP, very common/cheap) works as a substitute.
- This is a bigger lift — worth doing only if time allows before the open day.

### 7.4 — Quick win: the one-resistor ratio fix — ✅ DONE
Applied: swapped Rf_A (TLC082 pin1↔pin2) from 5kΩ → 4.7kΩ, keeping R_in at 1.2MΩ → ratio = 255.3 (0.26% error, down from 240/6.7%). Carry 4.7kΩ forward as the finalized value for the PCB/stereo expansion.

### 7.5 — Power Supply Plan (Open Day)

**Does stereo change the uni dual-rail supply requirement?** No — the extra DAC0802s and the TLC084 add only ~30–50mA total to the ±5V analog rails, well within any bench supply's headroom. The PAM8403 doesn't add a second amp chip (it's stereo natively); its 5V rail current roughly scales with output power but stays comfortably within reach of any supply too.

**For the open day (no bench PSU available), split power into three independent wall-fed sources:**

1. **FPGA** — keep the existing DE0-CV barrel-jack adapter, unchanged.
2. **Analog ±5V rail** (4× DAC0802 + TLC084) — small dual-rail DC-DC module fed from a cheap 12V wall adapter: [DC-DC Step-Down Buck Converter, Dual ±5V/9V/12V/15V output, 7.5–28V input, 1A](https://www.aliexpress.com/i/3256803495594750.html?gatewayAdapt=4itemAdapt) — ~300mA/rail, plenty of margin.
3. **PAM8403 stereo amp** — runs natively on 5V via USB; power from any USB phone charger or power bank.

Splitting the class-D amp's (electrically noisy) 5V rail from the sensitive DAC/op-amp analog rails is good practice beyond convenience — reduces the chance of PAM8403 switching noise coupling into the DAC reference or summing stage. Three small wall-warts is also far easier to transport/set up at a booth than one bench supply.

---

## 8. Critical Reminders (carried over from prior docs)

- **GND bridge:** FPGA GPIO_0 GND pin (pin 12 or 30) **must** be bridged to the breadboard analog GND rail. All of these must share this rail: both DAC pins 1/2/15, TLC082 pins 3/5, LM386 pins 2/4, speaker return, ±5V supply common, pot-related caps' GND sides.
- **Reset quirk:** RESET_N does not reset SD card state mid-stream. If audio locks up or glitches persistently, use the physical power switch (full power cycle), not RESET_N.
- **Pre-power-on checks:** No continuity between +5V/GND, −5V/GND, +5V/−5V. Both DAC pin 13 → +5V, pin 3 → −5V. Electrolytic cap polarities correct (reversed polarity on the 10µF/220µF caps is a common cause of "loud static" or "silence" symptoms).

---

*Document version: 5 (June 2026). Full breadboard circuit verified (§3–§6), ratio
fix applied (§7.4). §7 now has sourced AliExpress parts for speakers, PAM8403
stereo amp, stereo op-amp consolidation, and a 3-way power supply plan (§7.5).*

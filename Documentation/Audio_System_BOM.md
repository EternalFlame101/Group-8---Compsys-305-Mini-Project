# Audio System — Bill of Materials & Wiring Reference (Living Document)

> **Status:** Post-submission continuation project. Goal: best possible loud + clear audio
> for university open day demo. Budget is flexible — upgrades welcome even if they
> overlap with existing parts.
>
> This document consolidates several earlier AI-assisted design passes (which disagreed
> with each other on some component values) into one canonical reference, cross-checked
> against the confirmed physical build. Items marked **[VERIFY]** need a DMM check against
> the breadboard — see Section 6.
>
> **→ Jump to [§9](#9-pcb-redesign--i2s--pcm5102a-architecture-final-order-list) for the
> final PCB order list (PCM5102A I2S DAC + TPA3116D2, ready to order).** §1–§8 document
> the current working DAC0802 breadboard, kept as a proven fallback.

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
| 5 (B1, MSB) | bit 7 | GPIO_0[15] |
| 6 (B2) | bit 6 | GPIO_0[14] |
| 7 (B3) | bit 5 | GPIO_0[13] |
| 8 (B4) | bit 4 | GPIO_0[12] |
| 9 (B5) | bit 3 | GPIO_0[11] |
| 10 (B6) | bit 2 | GPIO_0[10] |
| 11 (B7) | bit 1 | GPIO_0[9] |
| 12 (B8, LSB) | bit 0 | GPIO_0[8] |

### Low-Byte DAC (DAC0802 #2) — receives `dac_low`

| DAC0802 Pin | Signal | FPGA Connection |
|---|---|---|
| 5 (B1, MSB) | bit 7 | GPIO_0[7] |
| 6 (B2) | bit 6 | GPIO_0[6] |
| 7 (B3) | bit 5 | GPIO_0[5] |
| 8 (B4) | bit 4 | GPIO_0[4] |
| 9 (B5) | bit 3 | GPIO_0[3] |
| 10 (B6) | bit 2 | GPIO_0[2] |
| 11 (B7) | bit 1 | GPIO_0[1] |
| 12 (B8, LSB) | bit 0 | GPIO_0[0] |

**SD debug mirror removed:** GPIO_0[3:0] previously mirrored SPI signals (SD_CLK, CS, MOSI, MISO) for oscilloscope probing — this has been removed now that SD card reads are confirmed working. The full 16-bit DAC bus now sits contiguously on GPIO_0[15:0]. Unused pins GPIO_0[35:16] driven low / tri-stated.

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

## 8. Critical Reminders for the §1–§7 Breadboard (kept as fallback — see §9)

- **GND bridge:** FPGA GPIO_0 GND pin (pin 12 or 30) **must** be bridged to the breadboard analog GND rail. All of these must share this rail: both DAC pins 1/2/15, TLC082 pins 3/5, LM386 pins 2/4, speaker return, ±5V supply common, pot-related caps' GND sides.
- **Reset quirk:** RESET_N does not reset SD card state mid-stream. If audio locks up or glitches persistently, use the physical power switch (full power cycle), not RESET_N.
- **Pre-power-on checks:** No continuity between +5V/GND, −5V/GND, +5V/−5V. Both DAC pin 13 → +5V, pin 3 → −5V. Electrolytic cap polarities correct (reversed polarity on the 10µF/220µF caps is a common cause of "loud static" or "silence" symptoms).

---

## 9. PCB Redesign — I2S / PCM5102A Architecture (FINAL ORDER LIST)

> **This is the target design for the PCB.** It supersedes the DAC0802 /
> TLC082 / VREF / byte-ratio analog chain in §3–§5 entirely — that whole
> section becomes unnecessary. The §1–§8 breadboard (now ratio-corrected and
> fully working) stays as a proven fallback until this PCB is built and tested.

### 9.1 — Architecture overview

```
FPGA GPIO_0 (BCK, LRCK, DIN, GND)  ── signals only, no power
        │
        ▼
  PCM5102A module (GY-PCM5102)  ── I2S in, stereo line-level analog out, built-in filter
        │  (L, R analog, line level)
        ▼
  TPA3116D2 stereo amp module (XH-M567, 2×50W, 5–24V DC in)
        │
        ▼
  2× speakers (L, R) — off-PCB, screw/JST terminals

Power rail (single 12–24V DC input, see §9.4):
        │
        ├──► TPA3116D2 module (direct)
        └──► Buck converter (→5V) ──► PCM5102A module
```

One PCM5102A handles **both** stereo channels via I2S time-division — no second
DAC, no summing op-amp stage, no ±5V analog rail, no byte-weighting resistor
ratio. The TPA3116D2 replaces the PAM8403 for a large jump in available power
(2×50W vs 2×3W) — see §9.4 for why this is realistic with chargers you already
own. Both modules mount on the carrier PCB via header sockets (so they're
swappable/replaceable, and you don't need to hand-solder TSSOP-20/SOP-16/QFN parts).

### 9.2 — Carrier PCB Order List

> **Link rot note:** AliExpress numeric item IDs get delisted/relisted often —
> by order time, some links below may 404. When that happens, search the
> bolded term for that row and pick a listing with **1,000+ orders, 4.5★+,
> and (for the amp) photos showing "TPA3116D2" actually printed on the chip**
> (cheap TPA3118/unbranded substitutes sometimes get listed under the same title).

| # | Component | Qty | Notes / Source |
|---|---|---|---|
| 1 | GY-PCM5102 I2S DAC module | 1 | [AliExpress link](https://www.aliexpress.com/item/1005006104038963.html) — 112dB SNR, built-in filter, both channels. Search term: **"GY-PCM5102 I2S DAC module"** |
| 2 | TPA3116D2 stereo amp module (XH-M567, 2×50W, **DC 12-24V confirmed**) | 1 | "1~2PCS XH-M567 TPA3116D2 Dual-channel Stereo... 50W*2" — NZ$6.35, 4.7★ (785 reviews, 4,000+ sold), a verified review confirms genuine TPA3116D2 chip. Swapped from XH-M189 (same chip/rating, far better track record). Spec tab confirms DC 12-24V input — matches §9.4 power plan exactly. **On arrival**: note whether audio input is RCA or screw-terminal/pads — affects how PCM5102A's output wires to it (doesn't change the overall plan). |
| 3 | Adjustable DC-DC buck converter (LM2596-ADJ), ~3-40V in → 3A out (powers PCM5102A) | 1 | "LM2596 DC-DC Step Down Converter Module 3A adjustable... LM2596S-ADJ" — select **LM2596 SMD** variant — NZ$2.66 (NZ$2.01 each ≥10pcs), 4.8★ (164 reviews, 2,000+ sold). LM2596-ADJ input range comfortably covers the 12-24V rail, output adjustable down to ~1.25V, 3A out is far more than needed. **On arrival, before connecting to the PCM5102A**: power it from the 12-24V rail alone, use a multimeter on its output, and turn the trim pot until it reads **5V** — these default near their max output, so skipping this could damage the DAC module. Most GY-PCM5102 modules have their own onboard 5V→3.3V regulator, so 5V in is enough — check your module's silkscreen too. |
| 4 | 2×20 (40-pin) 2.54mm double-row female pin header | 1 | "2.54mm Double Row Straight Female 2-40P Pin Header Socket Connector" — select **20Pin** (= 2×20 = 40 total). 4.9★ (182 reviews, 2,000+ sold). Mates with DE0-CV GPIO_0 — this is your "header grill" (signal/ground only — see §9.3) |
| 5 | 2.54mm single-row female header strips, breakable (for socketing modules) | 1 pack | "2.54mm Pitch Single Row Female 2-40P PCB Socket Header Strip" — select **40P 10Pcs** (NZ$7.82), 4.9★ (156 reviews, 3,000+ sold). Snap to length to match each module's pin count once they arrive — 10×40-pin strips is plenty for all 3 modules plus spares |
| 6 | 2-pin PCB screw terminal block (speaker L/R out) | 2 | "10/50PCS PCB Terminal Block Connector Pitch 5.0mm KF301... 2P 3P Screw Terminal Blocks Assortment Kit" — select **2P Green, 10PCS** (NZ$4.68, 4.9★, 1102 reviews, 10,000+ sold). Same product covers #6 and #7 — 3 terminals needed total (2 here + 1 below), 10pcs gives spares |
| 7 | 2-pin PCB screw terminal block (12–24V DC power input) | 1 | Same KF301 kit as #6, 1 more of the 2P terminals. The **single** power input for the whole audio PCB — feeds the TPA3116D2 module and the buck converter (#3) in parallel. See §9.4 for what to plug into it. |
| 8 | USB-C PD trigger board, fixed-voltage selectable (9/12/15/20V) | 1 pack (5pcs) | "5PCS PD/QC Decoy Board USB-C PD Trigger Board Module... To 12v" — NZ$8.67, 4.9★ (197 reviews, 3,000+ sold). Supports PD3.0/2.0 + QC, max 5A. **Ships set to 12V by default** — short the correct pads (or move the small resistor, per included manual) to set it to **20V**. Lets your 45W Samsung charger output 20V instead of its default 5V, so it can plug into #7. This is your portable power option. 5pcs gives spares — worth testing each one, per reviews. |
| 9 | Power-on LED + ~330Ω resistor | 1 each | Optional but nice for a demo board |
| 10 | 3" (78mm) full-range speaker pair, 8Ω, 10W/20W | 1 pair | "2 Pcs 3 Inch 78mm Full Range Audio Speakers 8 Ohm 20W Bubble Edge..." — NZ$26.82/lot, 4.7★ (152 reviews, 900+ sold). Reviews confirm real bass/full-range character for the size. 78mm dia × 37mm depth. Proportionate to the rest of the list (~$39 total). Needs small sealed enclosures — see §9.7 (now sized for this smaller driver). |

### 9.3 — Signal Map (FPGA GPIO_0 → PCB)

Only **4 connections** needed from the FPGA header — signals + a shared ground
reference. Power for the audio PCB comes from its own connector (§9.4), **not**
from the FPGA header.

| GPIO_0 Signal | Destination | Notes |
|---|---|---|
| BCK (bit clock) | PCM5102A module BCK pin | Generated by new VHDL I2S transmitter |
| LRCK (word select) | PCM5102A module LRCK/LCK pin | 44.1kHz, 50% duty — selects L vs R |
| DIN (serial data) | PCM5102A module DIN pin | 16-bit samples, MSB-first, I2S format |
| GND | Carrier PCB ground | Shared ground reference between FPGA and audio PCB — still required even with separate power |

> **Module config pins (SCK, FMT, XSMT, FLT, DEMP):** many GY-PCM5102 boards
> pre-configure these via onboard resistors (SCK grounded for internal-PLL
> mode, FMT for I2S format, XSMT pulled up for un-mute). Check your specific
> module's silkscreen/datasheet when it arrives — if pre-configured, you don't
> need to route these to the FPGA at all.

This frees up essentially all of GPIO_0[15:0] (the old parallel DAC bus) and
all of GPIO_1 for future use — debug LEDs, a second I2S link, etc.

### 9.4 — Power Architecture (single 12–24V rail, TPA3116D2)

- **FPGA**: keeps its existing barrel-jack adapter — completely separate from
  the audio PCB, unchanged.
- **Audio PCB**: ONE 12–24V DC input (#7, screw terminal) feeds the TPA3116D2
  module directly, and a small buck converter (#3) drops the same rail to 5V
  for the PCM5102A module.

**Two ways to provide that 12–24V**, into the same screw terminal (use only
one at a time):

1. **Bench/lab supply, if available on the day** — set it anywhere in
   12–24V. Higher = more power from the TPA3116D2 (24V gets you closest to
   its full rated 2×50W). Just connect +/− to the screw terminal. The uni's
   bench supplies are typically current-limited to ~3A, which is plenty —
   at 24V that's 72W, well above what the amp draws at normal/loud demo
   volumes. **This is actually the best-case power source** — better than
   the portable PD-trigger option below.
2. **Portable: your 45W Samsung charger + the PD trigger board (#8)** — set
   the trigger board's DIP switches to **20V**. Plug the charger into the
   trigger board's USB-C input; the trigger board negotiates 20V/2.25A
   (45W) from the charger via USB-PD and outputs it on wires you connect to
   the screw terminal. 20V is comfortably inside the TPA3116D2's 5–24V range
   and gets you most of the way to its full power — a huge step up from the
   PAM8403's 3W/channel.

**Why this works so well with your chargers:** a "dumb" connection (plain USB
cable) only ever gives 5V — that's why the PAM8403-era plan was stuck at 5V.
The PD trigger board is what unlocks the charger's higher-voltage modes
(your 45W charger supports 5V/9V/15V/20V via USB-PD). At 20V@2.25A the
charger can supply 45W — plenty of *average* power for a demo, even though
the TPA3116D2's absolute peak capability (2×50W ≈ 100W at full clip) is
higher; music has a high peak-to-average ratio, and the volume knob keeps you
out of clipping anyway. If you ever can't get the PD trigger board, your 15W
charger's 9V mode still works (9V is within the 5–24V range, just lower
power, roughly comparable to a small bookshelf amp).

**Speaker headroom:** the 3" 8Ω/20W speakers (#10) are rated well below the
TPA3116D2's ceiling — that's normal and expected (amps are usually rated
higher than the speakers they drive). You'll run the volume well below the
amp's max, which is exactly where it sounds cleanest anyway.

### 9.5 — VHDL Changes Required

- **Remove**: `dac_high`/`dac_low` parallel output logic, GPIO_0[15:0] DAC bus
  assignments.
- **Add**: I2S transmitter module —
  - Generate BCK ≈ 2.8224MHz (64×Fs @ 44.1kHz, 32-bit slots) or 1.4112MHz
    (32×Fs, 16-bit slots) from CLOCK_50 via clock divider.
  - Generate LRCK at 44.1kHz, 50% duty cycle.
  - Shift register serializes each 16-bit sample MSB-first, aligned to I2S
    timing (data starts 1 BCK cycle after each LRCK edge).
  - Reference implementation: [dwjbosman/I2S_sender (VHDL)](https://github.com/dwjbosman/I2S_sender).
- **Stereo source**: initially can duplicate the existing mono sample to both
  L and R channels; full stereo requires re-encoding the SD card as
  interleaved L/R 16-bit PCM and feeding each channel separately.

### 9.6 — Mechanical

- Carrier PCB is shaped as a "shield" with the 2×20 female header (#6) on its
  underside, plugging directly onto the DE0-CV's GPIO_0 male header.
- If GPIO_0 has a plastic shroud/cover, remove it for the shield to seat flush
  (as you planned).
- Mount the two breakout modules (#1, #2) flat on the carrier PCB via the
  header sockets (#5) — keeps them serviceable/replaceable.
- The XH-M189 (#2) is physically larger than the PAM8403 board and has a
  small heatsink on the TPA3116D2 chip — leave clearance above it and don't
  block airflow around the heatsink when laying out the carrier PCB.
- Speaker terminals (#6) and the power input screw terminal (#7) go on the
  PCB edge for easy cabling to the off-board speakers and power source.

### 9.7 — Speaker Enclosures (3D Printed)

The 3" drivers (#10) need a sealed enclosure each — bare drivers sound thin
and lose almost all their bass. 3D printing is a good fit here: small custom
boxes that can sit neatly next to the FPGA on the demo table.

**Driver dimensions:** 78mm (D) × 37mm (H) per the listing. A driver this
size only needs a small box — target **~0.5-1.5L sealed internal volume**
(roughly 10×10×12cm), which is small enough to print as a **single piece**
on most printer beds (no front/back split needed). Confirm the actual cutout
diameter on arrival before finalizing the front baffle hole.

- **Single-piece print**: at this size the whole enclosure (minus a small
  rear access panel for wiring) can usually print in one go — much simpler
  than the split-shell approach a bigger driver would need.
- **Walls ≥3mm with internal bracing** on the front baffle and back panel —
  thin printed walls buzz/resonate at volume, undermining clarity.
- **Airtightness**: 4+ perimeters and high infill get you most of the way;
  run a thin bead of silicone or hot glue along internal seams, and add a
  thin foam gasket between the driver's flange and the baffle cutout.
- **Sealed, not ported**: simpler to print reliably airtight, no port-length
  tuning required, still gives tight/clear bass — right call for a demo box.
- **Acoustic stuffing**: a handful of polyester fiberfill or acoustic foam
  inside each box reduces internal standing waves — cheap clarity win.

---

*Document version: 12 (June 2026). Item 3 (buck converter) swapped to an
LM2596-ADJ module (NZ$2.66, 4.8★/164 reviews/2,000+ sold) — better-reviewed
and cheaper than the previous pick, same 5V trim-pot configuration step
required on arrival. §9 amp upgraded from PAM8403 (2×3W) to
TPA3116D2 (XH-M567, 2×50W, swapped from XH-M189 for a far better-reviewed
listing with the same chip/rating). Power architecture changed to a single
12–24V rail: a USB-C PD trigger board (set to 20V) lets the existing 45W
Samsung charger feed the amp directly at near-full power, with a buck
converter dropping the same rail to 5V for the PCM5102A. Speakers settled on
a 3" (78mm) 8Ω 10W/20W pair at NZ$26.82/lot — proportionate to the rest of
the ~$39 order list, after the 5.25" AIYIMA options (40-50W aluminum-basin/
cone pairs, NZ$79-128) turned out disproportionately expensive — with §9.7
updated for a small single-piece sealed enclosure (~0.5-1.5L each). All
order-list items (§9.2) now have specific, reviewed listings selected with
the user during shopping — BOM is fully settled and ready to order.*

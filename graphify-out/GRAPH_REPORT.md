# Graph Report - Group-8---Compsys-305-Mini-Project  (2026-07-14)

## Corpus Check
- 13 files · ~159,354 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 166 nodes · 157 edges · 24 communities (20 shown, 4 thin omitted)
- Extraction: 100% EXTRACTED · 0% INFERRED · 0% AMBIGUOUS
- Token cost: 0 input · 0 output

## Graph Freshness
- Built from commit: `b6937752`
- Run `git rev-parse HEAD` and compare to check if the graph is stale.
- Run `graphify update .` after code changes (no API cost).

## Community Hubs (Navigation)
- COMPSYS 305 Mini Project – Full Technical Context Document
- Coding Conventions
- Audio System — Bill of Materials & Wiring Reference (Living Document)
- 18. Key Design Decisions and Trade-offs
- 9. PCB Redesign — I2S / PCM5102A Architecture (FINAL ORDER LIST)
- 8. Moving_Object — Moving_Object.vhd (Per Lane × 3)
- 10. DAC0802 Carrier PCB (Board 1) — Designed & Ordered
- 12. 3D-Printed Enclosure — Design (July 2026)
- 5. Output Stage — Coupling, Volume, LM386, Speaker
- 7. Open-Day Upgrade Path (Loud + Clear, Budget Flexible)
- 7. Player — Player.vhd
- 6. Verification Checklist (use your DMM)
- 16. Audio System
- 6. Game Logic FSM — Game_Master.vhd
- 17. Synthesis Results
- 4. Clock Domains
- Convert_Images_To_mif.py
- Video_PLL_0002
- README.md
- ncsim_setup.sh
- vcsmx_setup.sh

## God Nodes (most connected - your core abstractions)
1. `COMPSYS 305 Mini Project – Full Technical Context Document` - 22 edges
2. `Coding Conventions` - 16 edges
3. `Audio System — Bill of Materials & Wiring Reference (Living Document)` - 13 edges
4. `11. §9 Shield PCB — Design Kickoff (July 2026)` - 9 edges
5. `18. Key Design Decisions and Trade-offs` - 9 edges
6. `9. PCB Redesign — I2S / PCM5102A Architecture (FINAL ORDER LIST)` - 8 edges
7. `8. Moving_Object — Moving_Object.vhd (Per Lane × 3)` - 8 edges
8. `10. DAC0802 Carrier PCB (Board 1) — Designed & Ordered` - 7 edges
9. `5. Output Stage — Coupling, Volume, LM386, Speaker` - 6 edges
10. `7. Open-Day Upgrade Path (Loud + Clear, Budget Flexible)` - 6 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Import Cycles
- None detected.

## Communities (24 total, 4 thin omitted)

### Community 0 - "COMPSYS 305 Mini Project – Full Technical Context Document"
Cohesion: 0.07
Nodes (27): 10. Obstacle Spawning — Spawn_Control.vhd + Wave_ROM.vhd + LFSR, 11. Input Handling, 12. Start Screen — Start_Screen.vhd, 13. End Screen — End_Screen.vhd, 14. HUD Overlay — HUD_Overlay.vhd, 15. Game Timer — Game_Timer.vhd, 19. File Structure Reference, 1. Project Brief vs. What We Actually Built (+19 more)

### Community 1 - "Coding Conventions"
Cohesion: 0.08
Nodes (23): 10. Comments (Inline and Sectional), 11. Signal Declarations, 12. General Style Rules, 1. File Header Block, 2. Library Declarations, 3. Naming Conventions, 4. Indentation and Spacing, 5. Entity Declarations (+15 more)

### Community 2 - "Audio System — Bill of Materials & Wiring Reference (Living Document)"
Cohesion: 0.11
Nodes (17): 11.1 — Physical Architecture (Finalized), 11.2 — Dual-Source I2S Mux Architecture (Pico 2W + FPGA), 11.3 — Case Design Concept, 11.4 — Shield PCB Power Routing Summary, 11.5 — Board Type, 11.6 — Altium Progress (July 2026), 11.7 — Fab Order (JLCPCB), 11.8 — Remaining Tasks (+9 more)

### Community 3 - "18. Key Design Decisions and Trade-offs"
Cohesion: 0.22
Nodes (9): 18. Key Design Decisions and Trade-offs, 3D Perspective vs. Flat Side-Scroller, Fractional Stepping for Object Speed, GLOBAL Buffer on video_clock, Input Gating, LFSR for Pseudo-Random Spawning, Pipeline Registers Inserted for Timing (Not Function), Precomputed LUTs vs. Runtime Math (+1 more)

### Community 4 - "9. PCB Redesign — I2S / PCM5102A Architecture (FINAL ORDER LIST)"
Cohesion: 0.25
Nodes (8): 9.1 — Architecture overview, 9.2 — Carrier PCB Order List, 9.3 — Signal Map (FPGA GPIO_1 → PCB), 9.4 — Power Architecture (single 12–24V rail, TPA3116D2), 9.5 — VHDL Changes Required, 9.6 — Mechanical, 9.7 — Speaker Enclosures (3D Printed), 9. PCB Redesign — I2S / PCM5102A Architecture (FINAL ORDER LIST)

### Community 5 - "8. Moving_Object — Moving_Object.vhd (Per Lane × 3)"
Cohesion: 0.25
Nodes (8): 3D Frustum Rendering, 8. Moving_Object — Moving_Object.vhd (Per Lane × 3), Distance and Speed Management, Object Geometry — Object_ROM.vhd, Object Type Colors, Overflow/Underflow Protection, Perspective Scaling — Perspective_ROM.vhd, Pipeline Architecture

### Community 6 - "10. DAC0802 Carrier PCB (Board 1) — Designed & Ordered"
Cohesion: 0.29
Nodes (7): 10.1 — Key Design Decisions vs. Breadboard, 10.2 — Board Specs, 10.3 — Fab Order (JLCPCB), 10.4 — Breadboard Fixes Carried Into the PCB Layout, 10.5 — Breadboard Re-Verification (post-PCB-order, same fixes applied to breadboard) — ✅ RESOLVED, 10.6 — Remaining Tasks, 10. DAC0802 Carrier PCB (Board 1) — Designed & Ordered

### Community 7 - "12. 3D-Printed Enclosure — Design (July 2026)"
Cohesion: 0.33
Nodes (6): 12.1 — Overall Concept, 12.2 — Speaker Towers (Left + Right) — ✅ Designed, 12.3 — Center Box — IN PROGRESS (outsourced to friend), 12. 3D-Printed Enclosure — Design (July 2026), 12.4 — Knob Extensions — TO DO, 12.5 — Remaining Tasks

### Community 8 - "5. Output Stage — Coupling, Volume, LM386, Speaker"
Cohesion: 0.33
Nodes (6): 5. Output Stage — Coupling, Volume, LM386, Speaker, Coupling capacitor (TLC082 → LM386), LM386N-1, Output coupling cap → Speaker, Speaker, Volume potentiometer (10kΩ) — **CONFIRMED: Configuration A (signal-path divider)**

### Community 9 - "7. Open-Day Upgrade Path (Loud + Clear, Budget Flexible)"
Cohesion: 0.33
Nodes (6): 7.1 — Speaker upgrade (highest impact for "loud") — sourced, 7.2 — Amplifier upgrade: PAM8403 module — sourced, 7.3 — Stereo expansion (if you want it for the open day "wow" factor) — sourced, 7.4 — Quick win: the one-resistor ratio fix — ✅ DONE, 7.5 — Power Supply Plan (Open Day), 7. Open-Day Upgrade Path (Loud + Clear, Budget Flexible)

### Community 10 - "7. Player — Player.vhd"
Cohesion: 0.33
Nodes (6): 7. Player — Player.vhd, Animation System (24 Sprite ROMs), Cross-Domain Synchronization (Critical), Dive and Fast-Drop, Jump — Jump_Offset_LUT.vhd, Lane Shifting

### Community 11 - "6. Verification Checklist (use your DMM)"
Cohesion: 0.40
Nodes (5): 6.1 — Pot wiring — ✅ DONE, 6.2 — Summing stage resistors — ✅ DONE, 6.3 — COMP cap (10nF) — ✅ DONE, 6.4 — Output coupling cap — ✅ DONE, 6. Verification Checklist (use your DMM)

### Community 12 - "16. Audio System"
Cohesion: 0.40
Nodes (5): 16. Audio System, Audio Gating, Audio Playback — Audio_Playback.vhd, Jukebox (Top_Level process), SD Card — SD_Init.vhd + SPI_Master.vhd

### Community 13 - "6. Game Logic FSM — Game_Master.vhd"
Cohesion: 0.40
Nodes (5): 6. Game Logic FSM — Game_Master.vhd, Lives System, Scoring, Speed Escalation (Combinational on Score), States

### Community 14 - "17. Synthesis Results"
Cohesion: 0.50
Nodes (4): 17. Synthesis Results, Resource Utilization, Timing Performance, Why DSP Usage is High

### Community 15 - "4. Clock Domains"
Cohesion: 0.50
Nodes (4): 4. Clock Domains, CLOCK_50 (50 MHz), Cross-Domain Signal Handling, video_clock / Pixel Clock (25 MHz)

### Community 16 - "Convert_Images_To_mif.py"
Cohesion: 0.83
Nodes (3): convert_cat2_folder(), get_luminance(), image_to_mif()

## Knowledge Gaps
- **123 isolated node(s):** `altera_pll`, `ncsim_setup.sh script`, `vcsmx_setup.sh script`, `1. Confirmed Physical Inventory (as of June 2026)`, `High-Byte DAC (DAC0802 #1) — receives `dac_high`` (+118 more)
  These have ≤1 connection - possible missing edges or undocumented components.
- **4 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `COMPSYS 305 Mini Project – Full Technical Context Document` connect `COMPSYS 305 Mini Project – Full Technical Context Document` to `18. Key Design Decisions and Trade-offs`, `8. Moving_Object — Moving_Object.vhd (Per Lane × 3)`, `7. Player — Player.vhd`, `16. Audio System`, `6. Game Logic FSM — Game_Master.vhd`, `17. Synthesis Results`, `4. Clock Domains`?**
  _High betweenness centrality (0.159) - this node is a cross-community bridge._
- **Why does `Audio System — Bill of Materials & Wiring Reference (Living Document)` connect `Audio System — Bill of Materials & Wiring Reference (Living Document)` to `9. PCB Redesign — I2S / PCM5102A Architecture (FINAL ORDER LIST)`, `10. DAC0802 Carrier PCB (Board 1) — Designed & Ordered`, `12. 3D-Printed Enclosure — Design (July 2026)`, `5. Output Stage — Coupling, Volume, LM386, Speaker`, `7. Open-Day Upgrade Path (Loud + Clear, Budget Flexible)`, `6. Verification Checklist (use your DMM)`?**
  _High betweenness centrality (0.099) - this node is a cross-community bridge._
- **Why does `18. Key Design Decisions and Trade-offs` connect `18. Key Design Decisions and Trade-offs` to `COMPSYS 305 Mini Project – Full Technical Context Document`?**
  _High betweenness centrality (0.038) - this node is a cross-community bridge._
- **What connects `altera_pll`, `ncsim_setup.sh script`, `vcsmx_setup.sh script` to the rest of the system?**
  _123 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `COMPSYS 305 Mini Project – Full Technical Context Document` be split into smaller, more focused modules?**
  _Cohesion score 0.07142857142857142 - nodes in this community are weakly interconnected._
- **Should `Coding Conventions` be split into smaller, more focused modules?**
  _Cohesion score 0.08333333333333333 - nodes in this community are weakly interconnected._
- **Should `Audio System — Bill of Materials & Wiring Reference (Living Document)` be split into smaller, more focused modules?**
  _Cohesion score 0.1111111111111111 - nodes in this community are weakly interconnected._
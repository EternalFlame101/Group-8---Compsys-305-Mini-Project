# Coding Conventions

**Project:** Pusheen's Ploy
**Group:** Group 8 - Jasper's Knee
**Platform:** Terasic DE0-CV (Cyclone V) | Quartus Prime 18.1 Lite | VHDL

---

## Purpose

This document defines the coding conventions used across the Pusheen's Ploy
VHDL codebase. The goal is consistency: every file should look like it was
written by the same person, so that any teammate (or any AI assistant being
asked for help) can read, modify, or extend the code without having to first
decode someone else's style. If you're contributing code, match what's
described here. If you're merging in code that doesn't match, clean it up
before committing.

---

## Table of Contents

1. File Header Block
2. Library Declarations
3. Naming Conventions
4. Indentation and Spacing
5. Entity Declarations
6. Architecture Bodies
7. Component Declarations and Instantiations
8. Processes
9. Constants and Generics
10. Comments (Inline and Sectional)
11. Signal Declarations
12. General Style Rules

---

## 1. File Header Block

Every `.vhd` file starts with a fat comment block describing what the file
does. This sits **above** the `library` declarations. It must include:

- The entity/file name
- A short paragraph (2-6 lines) describing what the module does
- Any notable design decisions, assumptions, or quirks worth flagging
- The project name and group identifier

Use 78-character-wide dashed lines (`-- ----...----`) as the top and bottom
border. The block uses standard VHDL `--` line comments throughout.

**Template:**

```vhdl
-- ------------------------------------------------------------------------------
-- <Module_Name>
--   <One to two sentence summary of what this module does.>
--
--   <Optional second paragraph: design notes, assumptions, quirks, or any
--   non-obvious decisions that a future reader would want to know about.>
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
```

**Example (real, from `Background_Generator.vhd`):**

```vhdl
-- ------------------------------------------------------------------------------
-- Background_Generator
--   Renders a two-tone sky/ground background. The horizon is at vertical
--   pixel 320 (out of 480), giving a ground band on top and a sky band
--   below it.
--
--   This is purely combinational pixel-domain logic, but the clock and
--   vertical_sync ports are kept for symmetry with the other generator
--   blocks and in case animation is added later.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
```

---

## 2. Library Declarations

Library declarations come immediately after the file header, with no blank
line between the closing dashes of the header and `library IEEE;`. The
standard set used across this project is:

```vhdl
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;
```

Use `std_logic_unsigned` by default. Only switch to `std_logic_signed` if the
module genuinely needs signed arithmetic (e.g. a signed coordinate or signed
difference). Don't mix both in the same file.

Leave one blank line between the `use` clauses and the `entity` declaration.

---

## 3. Naming Conventions

| Element                    | Style                  | Example                              |
|----------------------------|------------------------|--------------------------------------|
| Entity names               | `PascalCase_With_Underscores` | `Mouse_Controller`, `VGA_Sync`, `Top_Level` |
| Architecture names         | `entity_name_behaviour` or descriptive snake_case | `vga_sync_behaviour`, `game_behaviour` |
| Component instance labels  | `PascalCase_With_Underscores` | `Player_Sprite_Renderer`, `Graphics : Graphics_Manager` |
| Ports and signals          | `snake_case`           | `pixel_row`, `vertical_sync`, `mouse_left_click` |
| Constants and generics     | `UPPER_SNAKE_CASE`     | `SCREEN_WIDTH`, `HORIZON_ROW`, `JUMP_PEAK_HEIGHT` |
| Process labels             | `PascalCase_With_Underscores` | `Character_Process`, `Frame_Stage_2`, `Moving` |
| FPGA pin names (Top_Level) | `UPPER_CASE` (matches DE0-CV) | `CLOCK_50`, `RESET_N`, `KEY`, `VGA_HS`, `LEDR` |

### No abbreviations

Spell signal names out in full. This is non-negotiable for any name that
appears in more than one file.

| Wrong              | Right                     |
|--------------------|---------------------------|
| `v_sync`           | `vertical_sync`           |
| `vsync_prev`       | `vertical_sync_previous`  |
| `h_count`          | `horizontal_count`        |
| `px_row`           | `pixel_row`               |
| `clk`              | `clock`                   |
| `rst`              | `reset`                   |

The exception is the DE0-CV's native pin names (`VGA_HS`, `VGA_VS`,
`PS2_DAT`, `SD_CLK`, etc.) which are taken verbatim from the board's
constraints file and must not be renamed.

### Pairs and triples

When a module exposes paired or triplet outputs, declare them on the same
line where it improves readability:

```vhdl
red_out, green_out, blue_out : out std_logic_vector(3 downto 0);
pixel_row, pixel_column      : in  std_logic_vector(9 downto 0);
clock, reset, vertical_sync  : in  std_logic;
```

---

## 4. Indentation and Spacing

- **Indent width:** 3 spaces. No tabs. Configure your editor to insert
  3 spaces on Tab. Files that come in with tabs or 2/4-space indent must
  be re-indented before being committed.
- **Architecture body:** Everything inside `architecture ... is ... begin`
  is indented 3 spaces relative to the `architecture` keyword.
- **Process bodies:** Statements inside a `process` are indented 3 spaces
  relative to the `process` keyword.
- **Nested control flow:** Each `if`/`elsif`/`else`/`case`/`when` body is
  indented another 3 spaces.
- **Blank lines:** One blank line between logical sections within an
  architecture (e.g. between signal declarations and `begin`, between
  successive processes, between component instantiations). Avoid double
  blank lines.

---

## 5. Entity Declarations

Format ports with the `: in`, `: out`, or `: inout` directions aligned in a
single column, and the type/signal width starting in the next aligned column.
The `port (` opens on the same line as the keyword, and the closing `);`
sits on its own line.

```vhdl
entity Top_Level is
   port (CLOCK_50            : in    std_logic;
         RESET_N             : in    std_logic;
         KEY                 : in    std_logic_vector(3 downto 0);
         SW                  : in    std_logic_vector(9 downto 0);
         VGA_HS, VGA_VS      : out   std_logic;
         VGA_R, VGA_G, VGA_B : out   std_logic_vector(3 downto 0);
         PS2_DAT             : inout std_logic;
         PS2_CLK             : inout std_logic;
         LEDR                : out   std_logic_vector(9 downto 0));
end entity Top_Level;
```

Group related ports together (clocks/resets, video, input devices, debug
outputs) and add a short `-- comment` between groups in larger entities.

Always use `end entity <Name>;` rather than just `end;` — it makes the file
greppable and helps when reading large files.

---

## 6. Architecture Bodies

The architecture has a strict ordering:

1. `component` declarations (if not in a separate package)
2. `constant` declarations
3. `signal` declarations
4. `begin`
5. Concurrent assignments and conditional assignments
6. `process` blocks
7. Component instantiations
8. `end architecture <name>;`

Section headers (see Comments below) separate each of these regions when the
file is non-trivial.

```vhdl
architecture game_behaviour of Top_Level is

   -- ========================================================================
   -- Component declarations
   -- ========================================================================
   component VGA_Sync is
      port (...);
   end component VGA_Sync;

   ...

   -- ========================================================================
   -- Constants
   -- ========================================================================
   constant SCREEN_WIDTH  : positive := 640;
   constant SCREEN_HEIGHT : positive := 480;

   -- ========================================================================
   -- Signals
   -- ========================================================================
   signal pixel_row    : std_logic_vector(9 downto 0);
   signal pixel_column : std_logic_vector(9 downto 0);

begin

   ...

end architecture game_behaviour;
```

---

## 7. Component Declarations and Instantiations

### Component declarations

Match the formatting of the source entity exactly. Direction column and type
column aligned.

```vhdl
component Player is
   generic (SCREEN_WIDTH        : positive := 640;
            SCREEN_HEIGHT       : positive := 480;
            SPRITE_SIZE         : positive := 32;
            SPRITE_SCALE        : positive := 4;
            WALK_FRAME_DURATION : positive := 5;
            JUMP_TOTAL_FRAMES   : positive := 120;
            JUMP_PEAK_HEIGHT    : positive := 60);
   port (clock, reset, vertical_sync           : in  std_logic;
         pixel_row, pixel_column               : in  std_logic_vector(9 downto 0);
         mouse_left_click                      : in  std_logic;
         player_red, player_green, player_blue : out std_logic_vector(3 downto 0);
         player_lane                           : out std_logic_vector(1 downto 0);
         player_state                          : out std_logic);
end component Player;
```

### Component instantiations

The instance label is `PascalCase`. Both `generic map` and `port map` have
their `=>` arrows aligned in a single column. The closing `);` sits at the
end of the last mapped port.

```vhdl
Player_Sprite_Renderer : Player
   generic map (SCREEN_WIDTH  => 640,
                SCREEN_HEIGHT => 480,
                SPRITE_SIZE   => 32,
                SPRITE_SCALE  => 4)
   port map (clock            => video_clock,
             reset            => not RESET_N,
             vertical_sync    => vertical_sync,
             pixel_row        => pixel_row,
             pixel_column     => pixel_column,
             mouse_left_click => left_click,
             player_red       => player_red,
             player_green     => player_green,
             player_blue      => player_blue,
             player_lane      => player_lane,
             player_state     => player_state);
```

Mapping discipline:

- Formal name (the port from the component) goes on the **left** of `=>`.
- Actual signal (the Top_Level signal) goes on the **right** of `=>`.
- When the formal and actual share a name, write them both anyway. It costs
  nothing and makes signals trivially greppable across files.

---

## 8. Processes

Every process has a label. The label is `PascalCase_With_Underscores` and
appears both at the `process` keyword and at the matching `end process`.

```vhdl
Character_Process : process (clock, pixel_row, pixel_column)
begin
   if rising_edge(clock) then
      character_on_register <= character_on;
   end if;
end process Character_Process;
```

For clocked logic the sensitivity list is just the clock (and async reset
if used). Combinational processes list every signal they read. If a process
gets large enough that it's hard to scan, split it.

---

## 9. Constants and Generics

Magic numbers are not allowed in the body of an architecture. If a value has
meaning, name it.

```vhdl
-- Don't:
sky_on <= '1' when (pixel_row >= "0101000000") else '0';

-- Do:
constant HORIZON_ROW : std_logic_vector(9 downto 0) := conv_std_logic_vector(320, 10);
sky_on <= '1' when (pixel_row >= HORIZON_ROW) else '0';
```

Tunable parameters belong as generics on the component, with default values
that match the expected typical use:

```vhdl
generic (SCREEN_WIDTH        : positive := 640;
         SCREEN_HEIGHT       : positive := 480;
         WALK_FRAME_DURATION : positive := 5;
         JUMP_TOTAL_FRAMES   : positive := 120;
         JUMP_PEAK_HEIGHT    : positive := 60);
```

If a generic is used to size a vector or drive a constant inside the
architecture, derive the constant once at the top of the architecture
rather than recomputing it inline.

---

## 10. Comments (Inline and Sectional)

### Section dividers

Use the `========` style for major section breaks inside an architecture or
between large processes:

```vhdl
   -- ========================================================================
   -- Per-pixel Stage 1 combinational: row derivations + all multiplies
   -- ========================================================================
```

Use the `--------` style for the entity-level header block and minor
sub-section breaks:

```vhdl
   -- ---------------------------------------------------------------------------
   -- Components
   -- ---------------------------------------------------------------------------
```

### Inline comments

Explain anything that isn't obvious from the code itself. The bar is "would
a teammate looking at this six weeks from now know what's going on without
asking?" If not, add a comment.

Comments live **above** the line they describe, not to the right of it:

```vhdl
-- Split the screen along the horizon row.
sky_on <= '1' when (pixel_row >= HORIZON_ROW) else '0';
```

End-of-line comments are fine only for trivially short notes (units, valid
ranges, etc.):

```vhdl
constant JUMP_TOTAL_FRAMES : positive := 120;   -- vsyncs, ~2 s at 60 Hz
```

### Flag non-obvious behaviour

If a block of code does something weird, suspicious, or workaround-y, say
so explicitly. Use a `NOTE:` or `TODO:` tag so it's greppable:

```vhdl
-- NOTE: pixel_row >= HORIZON_ROW gives sky below ground, which is
-- geometrically backwards. Flagged for review.

-- TODO: replace placeholder LFSR seed once gameplay is in place.
```

---

## 11. Signal Declarations

One signal per line. Type and width columns aligned for runs of related
signals.

```vhdl
   signal start_screen_red    : std_logic_vector(3 downto 0);
   signal start_screen_green  : std_logic_vector(3 downto 0);
   signal start_screen_blue   : std_logic_vector(3 downto 0);
   signal start_screen_active : std_logic;
   signal selected_mode       : std_logic_vector(1 downto 0);
   signal any_key_pressed     : std_logic;
```

Group signals by what they're for (one block for video signals, one for
mouse, one for FSM, etc.) with a short comment per group if the file is
large.

Edge-detect helper signals carry a `_previous` suffix:

```vhdl
   signal vertical_sync          : std_logic;
   signal vertical_sync_previous : std_logic;
```

Not `_prev`, not `_old`, not `_last`. `_previous`.

---

## 12. General Style Rules

- **Always use named `end` clauses.** `end entity Top_Level;`,
  `end architecture game_behaviour;`, `end process Moving;`,
  `end component Player;`. Never plain `end;`.
- **No mixed tabs and spaces.** Spaces only.
- **No trailing whitespace.** Strip it before committing.
- **One entity per file.** The file name matches the entity name exactly:
  `Mouse_Controller.vhd` contains `entity Mouse_Controller`.
- **Combinational vs clocked logic should be visually distinct.** Use
  `process(clock)` with `if rising_edge(clock) then` for clocked, and
  conditional signal assignment (`x <= a when cond else b;`) for simple
  combinational. Reserve combinational processes for cases that genuinely
  need them.
- **Reset polarity:** the board's `RESET_N` is active-low. Convert at the
  Top_Level boundary (`reset => not RESET_N`) so that submodules can treat
  their own `reset` port as active-high. Don't propagate active-low resets
  through the design.
- **No magic widths.** When slicing or sizing vectors, derive from a
  generic or a named constant. `(9 downto 0)` for pixel coordinates is
  fine because 640x480 is a project-wide constant, but anything more
  specific should be parameterised.
- **Keep architectures focused.** If a single architecture starts juggling
  more than three or four independent responsibilities, factor one of them
  out into its own component.

---

## Quick Reference: A Minimal Conforming File

This is what a small, properly-styled module looks like end to end:

```vhdl
-- ------------------------------------------------------------------------------
-- Example_Module
--   One-line summary of what this module does and why it exists.
--
--   Project: Pusheen's Ploy
--   Group:   Group 8 - Jasper's Knee
-- ------------------------------------------------------------------------------
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_arith.all;
use IEEE.std_logic_unsigned.all;

entity Example_Module is
   generic (WIDTH : positive := 10);
   port (clock, reset             : in  std_logic;
         enable                   : in  std_logic;
         data_in                  : in  std_logic_vector(WIDTH - 1 downto 0);
         data_out                 : out std_logic_vector(WIDTH - 1 downto 0));
end entity Example_Module;

architecture example_module_behaviour of Example_Module is

   signal data_register : std_logic_vector(WIDTH - 1 downto 0);

begin

   -- Latch data_in into data_register on every rising edge when enabled.
   Latch_Process : process (clock)
   begin
      if rising_edge(clock) then
         if reset = '1' then
            data_register <= (others => '0');
         elsif enable = '1' then
            data_register <= data_in;
         end if;
      end if;
   end process Latch_Process;

   data_out <= data_register;

end architecture example_module_behaviour;
```

---

*Last updated: May 2026. If you find yourself fighting these conventions,
raise it with the group before working around them.*

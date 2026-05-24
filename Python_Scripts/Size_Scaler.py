import math
from pathlib import Path

script_dir = Path(__file__).resolve().parent
project_root = script_dir.parent

# ── Shared parameters ──────────────────────────────────────────
DEPTH_MAX     = 160      # number of distance steps
SCREEN_CENTRE = 320      # horizontal centre of screen
HORIZON_Y     = 320      # scanline where horizon sits
SCREEN_H      = 480      # total screen height
POWER         = 1.1      # perspective curve shape

# ── Track spread parameters (reuse your existing curve) ─────────
MAX_SPREAD    = 310
MIN_SPREAD    = 5

# ── Object scale parameters ─────────────────────────────────────
MAX_OBJ_W     = 80       # half-width at camera
MIN_OBJ_W     = 2        # half-width at horizon
MAX_OBJ_H     = 120      # height at camera
MIN_OBJ_H     = 2        # height at horizon
OBJ_DEPTH_STEPS = 160     # how 'long' the object is

# ── Generate spread values (same curve as your track) ───────────
spread_values = []
for depth in range(1, DEPTH_MAX + 1):
    z      = depth / DEPTH_MAX
    spread = int(MIN_SPREAD + (MAX_SPREAD - MIN_SPREAD) * (z ** POWER))
    spread = max(spread, MIN_SPREAD)
    spread = min(spread, 320)
    spread_values.append(spread)

# ── Generate object scale values ────────────────────────────────
obj_w_values = []
obj_h_values = []
for depth in range(1, DEPTH_MAX + 1):
    z     = depth / DEPTH_MAX
    obj_w = int(MIN_OBJ_W + (MAX_OBJ_W - MIN_OBJ_W) * (z ** POWER))
    obj_h = int(MIN_OBJ_H + (MAX_OBJ_H - MIN_OBJ_H) * (z ** POWER))
    obj_w = max(obj_w, MIN_OBJ_W)
    obj_h = max(obj_h, MIN_OBJ_H)
    obj_w_values.append(obj_w)
    obj_h_values.append(obj_h)

# ── Generate lane X positions from spread ───────────────────────

obj_y_values = []

for i, spread in enumerate(spread_values):
    # Object Y bottom position — scales with depth index
    z     = (i + 1) / DEPTH_MAX
    obj_y = int(HORIZON_Y + (SCREEN_H - HORIZON_Y) * (z ** POWER))
    obj_y = min(obj_y, SCREEN_H - 1)
    obj_y_values.append(obj_y)

# Generate side and top values
top_height_values  = []
top_taper_values     = []
side_taper_values  = []
obj_w_back_values = []
obj_h_back_values = []

for i in range(DEPTH_MAX):
    obj_h  = obj_h_values[i]
    obj_w  = obj_w_values[i]
    spread = spread_values[i]
    
    # Spread at the back face of the object
    # The back face is OBJ_DEPTH_STEPS further away
    back_index  = max(i - OBJ_DEPTH_STEPS, 0)
    spread_back = spread_values[back_index]
    obj_w_back  = obj_w_values[back_index]  # width at back face
    obj_y_back  = obj_y_values[back_index]
    obj_h_back = obj_h_values[159]
    obj_y_front = obj_y_values[i]

    top_ext_pixels = spread - spread_back
    top_h_visual   = max(obj_h // 6, 1)
    top_h_depth    = max(obj_y_front - obj_y_back, 1)

    if top_h_depth > 0:
        top_taper = int((top_ext_pixels / top_h_depth) * 256)
    else:
        top_taper = 0
    top_taper = min(top_taper, 700)
    
    # Side taper uses full object depth not just top height
    # Side tapers over obj_h rows spanning top_ext_pixels
    if obj_h > 0:
        side_taper = int((top_ext_pixels / obj_h) * 256)
    else:
        side_taper = 0
    side_taper = min(side_taper, 700)
    
    top_height_values.append(top_h_visual)
    obj_w_back_values.append(obj_w_back)
    obj_h_back_values.append(obj_h_back)
    top_taper_values.append(top_taper)
    side_taper_values.append(side_taper)

# ── Write perspective (track spread) MIF ────────────────────────
output_dir = project_root / 'Images_To_mif' / 'mif'
output_dir.mkdir(parents=True, exist_ok=True)
with open(output_dir / 'perspective.mif', 'w') as f:
    f.write('WIDTH=10;\n')
    f.write('DEPTH=160;\n')
    f.write('ADDRESS_RADIX=UNS;\n')
    f.write('DATA_RADIX=UNS;\n')
    f.write('CONTENT BEGIN\n')
    for i, v in enumerate(spread_values):
        f.write(f'    {i} : {v};\n')
    f.write('END;\n')
print("perspective.mif written")

# ── Write object data MIF ────────────────────────────────────────
# Bit layout — 66 bits:
#   69 downto 60  obj_y        (10 bits)
#   59 downto 50  obj_h        (10 bits)
#   49 downto 40  obj_w        (10 bits)  front face width
#   39 downto 30  obj_w_back   (10 bits)  back face width
#   29 downto 20  top_height   (10 bits)
#   19 downto 10   top_taper    (10 bits)
#    9 downto 0   side_taper   (10 bits)

with open(output_dir / 'object_data.mif', 'w') as f:
    f.write('WIDTH=80;\n')
    f.write('DEPTH=160;\n')
    f.write('ADDRESS_RADIX=UNS;\n')
    f.write('DATA_RADIX=UNS;\n')
    f.write('CONTENT BEGIN\n')
    for i in range(DEPTH_MAX):
        packed = (
                (obj_h_back_values[i] << 70) |
                (obj_y_values[i]      << 60) |
                (obj_h_values[i]      << 50) |
                (obj_w_values[i]      << 40) |
                (obj_w_back_values[i] << 30) |
                (top_height_values[i] << 20) |
                (top_taper_values[i]  <<  10) |
                (side_taper_values[i] <<  0)
            )
        f.write(f'    {i} : {packed};\n')
    f.write('END;\n')
print("object_data.mif written")

# ── Print summary ────────────────────────────────────────────────
print(f"\nSpread   index 0 (horizon): {spread_values[0]}")
print(f"Spread   index 159 (camera): {spread_values[159]}")
print(f"\nObj W    index 159: {obj_w_values[159]}px half-width")
print(f"Obj H    index 0:   {obj_h_values[0]}px")
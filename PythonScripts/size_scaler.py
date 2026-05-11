import math

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
OBJ_DEPTH_STEPS = 30     # how 'long' the object is

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

for i in range(DEPTH_MAX):
    obj_h  = obj_h_values[i]
    obj_w  = obj_w_values[i]
    spread = spread_values[i]
    
    # Spread at the back face of the object
    # The back face is OBJ_DEPTH_STEPS further away
    back_index = max(i - OBJ_DEPTH_STEPS, 0)
    spread_back = spread_values[back_index]
    obj_y_back = obj_y_values[back_index]
    obj_y_front = obj_y_values[i]
    
    # Top extension = difference in spread between front and back
    top_ext_pixels = spread - spread_back
    
    top_h = max(obj_y_front - obj_y_back, 1)
    
    # Top taper rate = top_ext_pixels / top_h * 256
    if top_h > 0:
        top_taper = int((top_ext_pixels / top_h) * 256)
    else:
        top_taper = 0
    top_taper = min(top_taper, 300)
    
    # Side taper uses full object depth not just top height
    # Side tapers over obj_h rows spanning top_ext_pixels
    if obj_h > 0:
        side_taper = int((top_ext_pixels / obj_h) * 256)
    else:
        side_taper = 0
    side_taper = min(side_taper, 300)
    
    top_height_values.append(top_h)
    top_taper_values.append(top_taper)
    side_taper_values.append(side_taper)

# ── Write perspective (track spread) MIF ────────────────────────
with open('perspective2.mif', 'w') as f:
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
# New bit layout — 56 bits total:
#   55 downto 46  obj_y        (10 bits)
#   45 downto 36  obj_h        (10 bits)
#   35 downto 26  obj_w        (10 bits)
#   25 downto 16  top_height   (10 bits)
#   15 downto 8   top_ext      (8 bits)
#    7 downto 0   side_taper   (8 bits)

with open('object_data.mif', 'w') as f:
    f.write('WIDTH=56;\n')
    f.write('DEPTH=160;\n')
    f.write('ADDRESS_RADIX=UNS;\n')
    f.write('DATA_RADIX=UNS;\n')
    f.write('CONTENT BEGIN\n')
    for i in range(DEPTH_MAX):
        packed = (
            (obj_y_values[i]      << 46) |
            (obj_h_values[i]      << 36) |
            (obj_w_values[i]      << 26) |
            (top_height_values[i] << 16) |
            (top_taper_values[i]  <<  8) |
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
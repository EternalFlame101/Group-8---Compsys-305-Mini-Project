MAX_SPREAD = 310
MIN_SPREAD = 5
DEPTH_MAX  = 160
SCREEN_CENTRE = 320
POWER = 1.1

values = []

for depth in range(1, DEPTH_MAX + 1):
    # z is normalised depth 0.0 to 1.0
    # depth=1 is horizon (far), depth=160 is camera (near)
    z = depth / DEPTH_MAX

    # Parabolic spread using z^2
    # z^2 grows slowly near horizon, explosively near camera
    spread = int(MIN_SPREAD + (MAX_SPREAD - MIN_SPREAD) * (z ** POWER))

    spread = max(spread, MIN_SPREAD)
    spread = min(spread, 320)

    values.append(spread)

with open('perspective.mif', 'w') as f:
    f.write('WIDTH=10;\n')
    f.write('DEPTH=160;\n')
    f.write('ADDRESS_RADIX=UNS;\n')
    f.write('DATA_RADIX=UNS;\n')
    f.write('CONTENT BEGIN\n')
    for i, v in enumerate(values):
        f.write(f'    {i} : {v};\n')
    f.write('END;\n')
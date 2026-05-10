def rgb_to_ansi(r, g, b):
    # Simple ANSI 256-color approximation
    if r == g == b == 0:
        return 0  # black
    # Map to 256-color palette roughly
    return 16 + (r // 51) * 36 + (g // 51) * 6 + (b // 51)

def ascii_from_mif(mif_path):
    with open(mif_path, 'r') as f:
        lines = f.readlines()

    data_lines = []
    in_content = False
    for line in lines:
        line = line.strip()
        if line == 'Begin':
            in_content = True
            continue
        if line == 'End;':
            break
        if in_content and ':' in line:
            parts = line.split(':', 1)
            data_part = parts[1].split(';')[0].strip()
            data_lines.append(data_part)

    # Assuming 16x16 image
    width = 16
    height = 16
    blocks_x = (width + 7) // 8
    blocks_y = (height + 7) // 8

    # Build grid
    grid = [[None for _ in range(width)] for _ in range(height)]

    for address in range(len(data_lines)):
        binary = data_lines[address]
        rgba16 = int(binary, 2)
        r4 = (rgba16 >> 12) & 0xF
        g4 = (rgba16 >> 8) & 0xF
        b4 = (rgba16 >> 4) & 0xF
        a4 = rgba16 & 0xF
        r = r4 * 17
        g = g4 * 17
        b = b4 * 17
        a = a4 * 17

        # Reverse the block calculation
        block_index = address // 64
        local_index = address % 64
        bx = block_index % blocks_x
        by = block_index // blocks_x
        local_y = local_index // 8
        local_x = local_index % 8
        px = bx * 8 + local_x
        py = by * 8 + local_y

        if px < width and py < height:
            grid[py][px] = (r, g, b, a)

    print(f"ASCII preview from MIF: {mif_path}")
    print("Each character shows the pixel color (background) and opacity (character).")
    print()

    for y in range(height):
        for x in range(width):
            r, g, b, a = grid[y][x]
            ansi_color = rgb_to_ansi(r, g, b)
            if a == 0:
                char = ' '  # fully transparent
            elif a < 128:
                char = '░'  # semi-transparent
            else:
                char = '█'  # opaque
            print(f"\033[48;5;{ansi_color}m{char}\033[0m", end='')
        print()

if __name__ == '__main__':
    ascii_from_mif('mif_files/16x16test.mif')
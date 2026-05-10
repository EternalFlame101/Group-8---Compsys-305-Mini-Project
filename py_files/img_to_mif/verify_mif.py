from pathlib import Path
from PIL import Image
import argparse

def generate_ascii_from_image(image_path):
    img = Image.open(image_path).convert('RGBA')
    width, height = img.size
    ascii_lines = []
    for y in range(height):
        line = ''
        for x in range(width):
            r, g, b, a = img.getpixel((x, y))
            if a == 0:
                char = ' '  # fully transparent
            elif a < 128:
                char = '░'  # semi-transparent
            else:
                char = '█'  # opaque
            line += char
        ascii_lines.append(line)
    return ascii_lines

def decode_mif_pixel(binary):
    if len(binary) == 12:
        value = int(binary, 2)
        r4 = (value >> 8) & 0xF
        g4 = (value >> 4) & 0xF
        b4 = value & 0xF
        a4 = 0xF
    elif len(binary) == 16:
        value = int(binary, 2)
        r4 = (value >> 12) & 0xF
        g4 = (value >> 8) & 0xF
        b4 = (value >> 4) & 0xF
        a4 = value & 0xF
    else:
        raise ValueError(f"Unsupported MIF data width: {len(binary)} bits")
    return r4 * 17, g4 * 17, b4 * 17, a4 * 17


def generate_ascii_from_mif(mif_path, width=16, height=16):
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

    blocks_x = (width + 7) // 8
    blocks_y = (height + 7) // 8

    # Build grid with default transparent pixels
    grid = [[(0, 0, 0, 0) for _ in range(width)] for _ in range(height)]

    for address, binary in enumerate(data_lines):
        r, g, b, a = decode_mif_pixel(binary)

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

    ascii_lines = []
    for y in range(height):
        line = ''
        for x in range(width):
            _, _, _, a = grid[y][x]
            if a == 0:
                char = ' '  # fully transparent
            elif a < 128:
                char = '░'  # semi-transparent
            else:
                char = '█'  # opaque
            line += char
        ascii_lines.append(line)
    return ascii_lines

def pixel_by_pixel_verify(image_path, mif_path):
    img = Image.open(image_path).convert('RGBA')
    width, height = img.size

    with open(mif_path, 'r') as f:
        lines = f.readlines()

    # Skip header
    data_start = False
    address = 0
    mismatches = 0
    for line in lines:
        line = line.strip()
        if line == 'Begin':
            data_start = True
            continue
        if not data_start or line == 'End;':
            continue
        if ':' in line:
            parts = line.split(':', 1)
            addr_str = parts[0].strip()
            data_part = parts[1].split(';')[0].strip()
            binary = data_part

            r, g, b, a = decode_mif_pixel(binary)
            r4 = r // 17
            g4 = g // 17
            b4 = b // 17
            a4 = a // 17

            # Find pixel position
            block_x = (address // 64) % ((width + 7) // 8)
            block_y = (address // 64) // ((width + 7) // 8)
            local_x = (address % 64) % 8
            local_y = (address % 64) // 8
            px = block_x * 8 + local_x
            py = block_y * 8 + local_y

            if px < width and py < height:
                orig_r, orig_g, orig_b, orig_a = img.getpixel((px, py))
                orig_r4 = (orig_r + 8) // 17  # Round to nearest 4-bit
                orig_g4 = (orig_g + 8) // 17
                orig_b4 = (orig_b + 8) // 17
                orig_a4 = (orig_a + 8) // 17

                if r4 != orig_r4 or g4 != orig_g4 or b4 != orig_b4 or a4 != orig_a4:
                    mismatches += 1
                    print(f"Mismatch at ({px},{py}): MIF R{r} G{g} B{b} A{a} != Image R{orig_r} G{orig_g} B{orig_b} A{orig_a}")
            address += 1

    if mismatches == 0:
        print("✓ Pixel-by-pixel verification passed: All pixels match!")
    else:
        print(f"✗ Found {mismatches} mismatches.")

def verify_mif_ascii(image_path, mif_path):
    img = Image.open(image_path).convert('RGBA')
    width, height = img.size

    png_ascii = generate_ascii_from_image(image_path)
    mif_ascii = generate_ascii_from_mif(mif_path, width, height)

    print("PNG ASCII:")
    for line in png_ascii:
        print(line)
    print("\nMIF ASCII:")
    for line in mif_ascii:
        print(line)

    if png_ascii == mif_ascii:
        print("\n✓ ASCII representations match!")
    else:
        print("\n✗ ASCII representations differ.")

    # Also do pixel-by-pixel
    pixel_by_pixel_verify(image_path, mif_path)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Verify an image against a MIF file.')
    parser.add_argument('image_path', help='Original image file path')
    parser.add_argument('mif_path', help='MIF file path to verify')
    args = parser.parse_args()

    verify_mif_ascii(args.image_path, args.mif_path)
# Convert an image to a 64x64 MIF file (12-bit RGB 4:4:4, row-major order)

from pathlib import Path
from PIL import Image
import argparse


def image_to_mif(image_path, output_path=None, output_folder='mif_output', target_width=64, target_height=64):
    image_path = Path(image_path)
    if output_path is None:
        output_path = Path(output_folder) / f"{image_path.stem}.mif"
    else:
        output_path = Path(output_path)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    img = Image.open(image_path).convert('RGB')
    img = img.resize((target_width, target_height), Image.LANCZOS)
    width, height = img.size
    depth = width * height  # e.g. 64*64 = 4096

    with open(output_path, 'w') as f:
        f.write(f"Depth = {depth};\n")
        f.write("Width = 12;\n")
        f.write("Address_radix = dec;\n")
        f.write("Data_radix = bin;\n")
        f.write("Content\n")
        f.write("Begin\n")

        address = 0
        # Row-major order: matches ROM addressing in Sprites_Display
        # address = y * width + x
        for y in range(height):
            for x in range(width):
                r, g, b = img.getpixel((x, y))

                # Truncate 8-bit channels to 4-bit
                r4 = (r >> 4) & 0xF
                g4 = (g >> 4) & 0xF
                b4 = (b >> 4) & 0xF

                rgb12 = (r4 << 8) | (g4 << 4) | b4
                binary = format(rgb12, '012b')

                f.write(f"  {address} : {binary} ; -- R:{r4:X} G:{g4:X} B:{b4:X}\n")
                address += 1

        f.write("End;\n")

    print(f"Written {address} pixels to {output_path}")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Convert image to 12-bit RGB MIF file.')
    parser.add_argument('image_file', help='Input image file path')
    parser.add_argument('output_mif_path', nargs='?', default=None, help='Optional output MIF file path')
    parser.add_argument('--width',  type=int, default=64, help='Target width  (default: 64)')
    parser.add_argument('--height', type=int, default=64, help='Target height (default: 64)')
    args = parser.parse_args()

    image_to_mif(
        args.image_file,
        args.output_mif_path,
        target_width=args.width,
        target_height=args.height,
    )
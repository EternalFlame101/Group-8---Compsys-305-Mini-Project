from pathlib import Path
from PIL import Image
from collections import Counter
import argparse


def get_luminance(pixel):
    r, g, b = pixel
    return 0.299 * r + 0.587 * g + 0.114 * b


def image_to_mif(image_path, output_path=None, output_folder='mif', target_width=32, target_height=32, num_colours=None):
    image_path = Path(image_path)
    if output_path is None:
        output_path = Path(output_folder) / f"{image_path.stem}_set2_mif.mif"
    else:
        output_path = Path(output_path)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    img = Image.open(image_path).convert('RGB')
    img = img.resize((target_width, target_height), Image.LANCZOS)

    width, height = img.size
    depth = width * height

    # Truncate all pixels to 4-bit first
    pixels_4bit = [
        (min(15, (r + 8) >> 4), min(15, (g + 8) >> 4), min(15, (b + 8) >> 4))
        for r, g, b in img.getdata()
    ]

    if num_colours is not None:
        # Treat anything very dark as black
        BLACK = (0, 0, 0)
        non_black = [p for p in pixels_4bit if get_luminance(p) > 1]

        # Split non-black into dark and light bands
        dark  = [p for p in non_black if get_luminance(p) <= 7]
        light = [p for p in non_black if get_luminance(p) >  7]

        # Build palette: black + most common from each band
        palette = [BLACK]
        if dark:
            palette.append(Counter(dark).most_common(1)[0][0])
        if light:
            palette.append(Counter(light).most_common(1)[0][0])

        # If num_colours > 3, pull extra colours from non-black by frequency
        if num_colours > 3 and non_black:
            extras_needed = num_colours - len(palette)
            candidates = [c for c, _ in Counter(non_black).most_common(num_colours + extras_needed)
                         if c not in palette]
            palette += candidates[:extras_needed]

        def nearest(pixel):
            # Keep black pixels black
            if get_luminance(pixel) <= 1:
                return BLACK
            return min(palette, key=lambda c: sum((a - b) ** 2 for a, b in zip(pixel, c)))

        pixels_4bit = [nearest(p) for p in pixels_4bit]

    with open(output_path, 'w') as f:
        f.write(f"Depth = {depth};\n")
        f.write("Width = 12;\n")
        f.write("Address_radix = dec;\n")
        f.write("Data_radix = bin;\n")
        f.write("Content\n")
        f.write("Begin\n")

        for address, (r4, g4, b4) in enumerate(pixels_4bit):
            rgb12 = (r4 << 8) | (g4 << 4) | b4
            binary = format(rgb12, '012b')
            f.write(f"  {address} : {binary} ; -- R:{r4:X} G:{g4:X} B:{b4:X}\n")

        f.write("End;\n")

    print(f"Written {depth} pixels to {output_path}")
    if num_colours is not None:
        print(f"Palette used: {palette}")


def convert_cat2_folder(input_folder='img/cat2', output_folder='mif', target_width=32, target_height=32, num_colours=None):
    input_folder = Path(input_folder)
    supported_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff'}

    images = [f for f in input_folder.iterdir() if f.suffix.lower() in supported_extensions]

    if not images:
        print(f"No images found in {input_folder}")
        return

    for image_path in sorted(images):
        image_to_mif(
            image_path,
            output_path=None,
            output_folder=output_folder,
            target_width=target_width,
            target_height=target_height,
            num_colours=num_colours,
        )


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Convert all cat2 images to 12-bit RGB MIF files with _set2_mif suffix.')
    parser.add_argument('--input',   default='img/cat2',  help='Input folder containing cat2 images (default: img/cat2)')
    parser.add_argument('--output',  default='mif',       help='Output folder for MIF files (default: mif)')
    parser.add_argument('--width',   type=int, default=32, help='Target width (default: 32)')
    parser.add_argument('--height',  type=int, default=32, help='Target height (default: 32)')
    parser.add_argument('--colours', type=int, default=None, help='Reduce image to N colours (black + N-1 sprite colours)')
    args = parser.parse_args()

    convert_cat2_folder(
        input_folder=args.input,
        output_folder=args.output,
        target_width=args.width,
        target_height=args.height,
        num_colours=args.colours,
    )
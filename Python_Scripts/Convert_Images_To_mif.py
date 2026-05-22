from pathlib import Path
from PIL import Image
from collections import Counter
import argparse

script_dir = Path(__file__).resolve().parent
project_root = script_dir.parent


def get_luminance(pixel):
    r, g, b = pixel
    return 0.299 * r + 0.587 * g + 0.114 * b


def image_to_mif(image_path, output_path=None, output_folder='Images_To_mif/mif', target_width=64, target_height=64, num_colours=6):
    image_path = Path(image_path)
    if output_path is None:
        output_folder = Path(output_folder)
        if not output_folder.is_absolute():
            output_folder = project_root / output_folder
        output_path = output_folder / f"{image_path.stem}.mif"
    else:
        output_path = Path(output_path)
        if not output_path.is_absolute():
            output_path = project_root / output_path

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


def convert_cat2_folder(input_folder='Images_To_mif/Images/cat_walking', output_folder='Images_To_mif/mif', target_width=64, target_height=64, num_colours=6):
    input_folder = Path(input_folder)
    supported_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.gif', '.tiff'}

    if not input_folder.is_absolute():
        input_folder = project_root / input_folder

    if input_folder.is_file():
        images = [input_folder]
    elif input_folder.is_dir():
        images = [f for f in input_folder.iterdir() if f.suffix.lower() in supported_extensions]
    else:
        print(f"No images found in {input_folder}")
        return

    if not images:
        print(f"No images found in {input_folder}")
        return

    output_folder = Path(output_folder)
    if not output_folder.is_absolute():
        output_folder = project_root / output_folder

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
    parser = argparse.ArgumentParser(description='Convert all cat images to 12-bit RGB MIF files.')
    parser.add_argument('--input',   default='Images_To_mif/Images/cat_walking',  help='Input folder containing cat2 images under project root')
    parser.add_argument('--output',  default='Images_To_mif/mif',       help='Output folder for MIF files under project root')
    parser.add_argument('--width',   type=int, default=64, help='Target width (default: 64)')
    parser.add_argument('--height',  type=int, default=64, help='Target height (default: 64)')
    parser.add_argument('--colours', type=int, default=6, help='Reduce image to N colours (black + N-1 sprite colours)')
    args = parser.parse_args()

    convert_cat2_folder(
        input_folder=args.input,
        output_folder=args.output,
        target_width=args.width,
        target_height=args.height,
        num_colours=args.colours,
    )
# Converting a pixel art file in to 8x8 blocks to a mif file (if the file is larger than 8x8, then it will be split into multiple blocks and each block will be converted to a separate entry in the mif file)

from pathlib import Path
from PIL import Image
import argparse

def image_to_mif(image_path, output_path=None, output_folder='mif', include_alpha=False):
    image_path = Path(image_path)
    if output_path is None:
        output_path = Path(output_folder) / f"{image_path.stem}.mif"
    else:
        output_path = Path(output_path)

    output_path.parent.mkdir(parents=True, exist_ok=True)

    img = Image.open(image_path)
    if include_alpha:
        img = img.convert('RGBA')  # Red, Green, Blue, Alpha
    else:
        img = img.convert('RGB')  # Red, Green, Blue

    width, height = img.size

    # Calculate the number of 8x8 blocks
    blocks_x = (width + 7) // 8
    blocks_y = (height + 7) // 8
    total_blocks = blocks_x * blocks_y

    # Write the blocks to a mif file
    with open(output_path, 'w') as f:
        f.write("Depth = {};\n".format(total_blocks * 64))  # 8x8 = 64 pixels per block
        if include_alpha:
            f.write("Width = 16;\n")  # 16 bits per pixel (4 bits per channel: RRRRGGGGBBBBAAAA)
        else:
            f.write("Width = 12;\n")  # 12 bits per pixel (4 bits per channel: RRRRGGGGBBBB)
        f.write("Address_radix = oct;\n")
        f.write("Data_radix = bin;\n")
        f.write("Content\n")
        f.write("  Begin\n")

        address = 0
        for by in range(blocks_y):
            for bx in range(blocks_x):
                for y in range(8):
                    for x in range(8):
                        px = bx * 8 + x
                        py = by * 8 + y
                        if px < width and py < height:
                            pixel = img.getpixel((px, py))
                            if include_alpha:
                                r, g, b, a = pixel
                            else:
                                r, g, b = pixel
                                a = 255
                        else:
                            r, g, b, a = 0, 0, 0, 255
                        
                        # Convert 8-bit to 4-bit (divide by 16)
                        r4 = (r >> 4) & 0xF
                        g4 = (g >> 4) & 0xF
                        b4 = (b >> 4) & 0xF
                        
                        if include_alpha:
                            a4 = (a >> 4) & 0xF
                            rgba16 = (r4 << 12) | (g4 << 8) | (b4 << 4) | a4
                            binary = format(rgba16, '016b')
                            f.write("{:03o}  : {} ; % R:{} G:{} B:{} A:{} %\n".format(address, binary, r, g, b, a))
                        else:
                            rgb12 = (r4 << 8) | (g4 << 4) | b4
                            binary = format(rgb12, '012b')
                            f.write("{:03o}  : {} ; % R:{} G:{} B:{} %\n".format(address, binary, r, g, b))
                        address += 1

        f.write("End;\n")


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Convert an image to a MIF file using 8x8 blocks.')
    parser.add_argument('image_file', help='Input image file path')
    parser.add_argument('output_mif_path', nargs='?', default=None, help='Optional output MIF file path')
    parser.add_argument('--rgba', action='store_true', help='Include alpha channel and output 16-bit RGBA values')
    args = parser.parse_args()

    image_to_mif(args.image_file, args.output_mif_path, include_alpha=args.rgba)
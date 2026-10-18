"""Draw small freight interiors and props using Iskra's existing pixel palette."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/art/iskra'
ROOMS = {'freight': (640, 2816, 640, 352), 'holding': (1408, 2816, 640, 352)}
INK = (28, 23, 48)
BRASS = (190, 143, 73)
FONT = ImageFont.load_default()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ROOMS:
        im = Image.new('RGBA', (320, 176), INK)
        d = ImageDraw.Draw(im)
        d.rectangle((8, 8, 311, 167), fill=(76, 65, 54), outline=BRASS)
        for y in range(16, 168, 16):
            d.line((9, y, 310, y), fill=(62, 52, 46))
        for x in range(16, 312, 24):
            d.line((x, 9, x, 166), fill=(62, 52, 46))
        d.rectangle((8, 102, 311, 124), fill=(98, 79, 56))
        for x in (22, 294):
            d.rectangle((x, 16, x+3, 20), fill=(255, 220, 138))
        d.rectangle((132, 3, 190, 13), fill=INK, outline=BRASS)
        d.text((139, 4), 'FREIGHT' if name == 'freight' else 'STORE 6', font=FONT, fill=(255, 226, 168))
        # The upper shelving is decorative; the broad lower aisle remains open.
        for x in (36, 96, 222, 274):
            d.rectangle((x, 24, x+22, 43), fill=(111, 75, 46), outline=INK)
            d.line((x+2, 27, x+20, 40), fill=BRASS)
            d.line((x+20, 27, x+2, 40), fill=BRASS)
        # Pipes, stacked cargo and tools distinguish the working rooms from city streets.
        for x in (12, 306):
            d.line((x, 32, x, 136), fill=(41, 38, 42), width=5)
            d.line((x-1, 32, x-1, 136), fill=(142, 111, 69), width=2)
            for y in (48, 80, 132):
                d.rectangle((x-3, y, x+3, y+2), fill=BRASS)
        for x in (36, 96, 222, 274):
            d.line((x-2, 44, x+24, 44), fill=INK, width=2)
            d.line((x-2, 45, x-2, 53), fill=BRASS)
            d.line((x+24, 45, x+24, 53), fill=BRASS)
            d.rectangle((x+3, 19, x+16, 25), fill=(91, 65, 45), outline=INK)
        d.rectangle((66, 149, 253, 167), fill=(42, 36, 39), outline=BRASS)
        for x in range(73, 246, 24):
            d.rectangle((x, 154, x+17, 164), fill=(87, 68, 50), outline=INK)
            d.line((x+5, 157, x+12, 157), fill=BRASS)
        for x in range(60, 270, 12):
            d.line((x, 128, x+6, 128), fill=(163, 126, 68))
        if name == 'freight':
            d.rectangle((45, 80, 73, 98), fill=(90, 62, 43), outline=INK)
            d.line((46, 81, 72, 81), fill=BRASS)
            d.rectangle((50, 83, 64, 92), fill=(209, 191, 140), outline=(129, 113, 85))
            for y in (85, 88, 90):
                d.line((52, y, 61, y), fill=(83, 73, 63))
        else:
            d.line((216, 52, 302, 52), fill=BRASS, width=2)
            d.line((216, 52, 216, 99), fill=BRASS, width=2)
            for x in range(222, 302, 8):
                d.line((x, 43, x, 61), fill=(117, 117, 105))
            d.rectangle((229, 64, 244, 67), fill=(118, 100, 75), outline=INK)
            d.rectangle((260, 80, 275, 83), fill=(118, 100, 75), outline=INK)
        d.rectangle((18, 147, 38, 167), fill=(128, 98, 61), outline=BRASS)
        d.rectangle((280, 147, 301, 167), fill=(128, 98, 61), outline=BRASS)
        im.save(OUT / ('gang_' + name + '.png'))
    im = Image.new('RGBA', (16, 16))
    d = ImageDraw.Draw(im)
    d.rectangle((1, 2, 14, 14), fill=(126, 81, 44), outline=INK)
    d.rectangle((3, 4, 12, 12), outline=BRASS)
    d.line((3, 4, 12, 12), fill=BRASS)
    d.line((12, 4, 3, 12), fill=BRASS)
    im.save(OUT / 'gang_crate.png')
    im = Image.new('RGBA', (84, 44))
    d = ImageDraw.Draw(im)
    d.rectangle((2, 10, 81, 43), fill=(73, 65, 53), outline=INK)
    d.polygon([(0, 11), (14, 1), (69, 1), (83, 11)], fill=(54, 49, 44), outline=INK)
    d.line((5, 12, 78, 12), fill=BRASS)
    d.rectangle((19, 14, 65, 25), fill=INK, outline=BRASS)
    d.text((21, 15), 'STORE 6', font=FONT, fill=(255, 220, 138))
    d.rectangle((33, 28, 48, 43), fill=(35, 29, 29), outline=BRASS)
    for x in (9, 65):
        d.rectangle((x, 29, x+9, 36), fill=(241, 176, 72), outline=INK)
        d.line((x+3, 29, x+3, 36), fill=INK)
        d.line((x+6, 29, x+6, 36), fill=INK)
    d.rectangle((77, 30, 82, 43), fill=(42, 35, 31), outline=BRASS)
    im.save(OUT / 'gang_holding_exterior.png')
    print('Created Iskra freight rooms, Store 6 exterior and cargo prop')


if __name__ == '__main__':
    main()

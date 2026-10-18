"""Draw Hotel Kinova's room and sign in the existing Iskra pixel palette."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/art/iskra"
ROOM_ORIGIN = (64, 2816)
ROOM_SIZE = (384, 256)
# Furniture rectangles are in the half-size source image; the map draws at 2x.
FURNITURE = [(20, 18, 26, 42), (144, 18, 26, 42), (68, 22, 24, 14), (136, 88, 32, 16)]
# Lobby sits east of the city, clear of the investigation interiors.
LOBBY_ORIGIN = (3520, 2816)
LOBBY_SIZE = (384, 256)
LOBBY_FURNITURE = [(72, 56, 48, 18), (8, 24, 32, 48), (128, 128, 32, 12)]
INK = (28, 23, 48)
BRASS = (205, 158, 81)
CREAM = (241, 220, 171)
FONT = ImageFont.load_default()


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    im = Image.new("RGBA", (192, 128), INK)
    d = ImageDraw.Draw(im)
    d.rectangle((8, 8, 183, 119), fill=(111, 77, 52), outline=BRASS)
    for y in range(12, 120, 8):
        d.line((9, y, 182, y), fill=(88, 60, 46))
        for x in range(12 + (y % 16)*2, 182, 24):
            d.line((x, y, x, min(y+7, 119)), fill=(88, 60, 46))
    d.rectangle((62, 48, 128, 111), fill=(91, 61, 68), outline=(178, 133, 80))
    d.rectangle((66, 52, 124, 107), outline=(149, 106, 79))
    for x in (20, 144):
        d.rectangle((x, 18, x+25, 59), fill=(68, 43, 34), outline=INK)
        d.rectangle((x+3, 22, x+22, 30), fill=CREAM, outline=INK)
        d.rectangle((x+3, 32, x+22, 55), fill=(93, 130, 119), outline=INK)
        d.line((x+6, 34, x+6, 53), fill=(144, 176, 147))
        d.rectangle((x-6, 21, x-3, 24), fill=(255, 224, 149))
    d.rectangle((68, 22, 91, 35), fill=(119, 76, 44), outline=INK)
    d.rectangle((70, 24, 89, 27), outline=BRASS)
    d.rectangle((78, 28, 81, 31), fill=BRASS, outline=INK)
    d.rectangle((136, 88, 167, 103), fill=(128, 89, 52), outline=INK)
    d.rectangle((139, 91, 149, 98), fill=CREAM, outline=INK)
    d.ellipse((158, 90, 164, 96), fill=(229, 197, 135), outline=INK)
    d.rectangle((93, 117, 104, 127), fill=(164, 117, 65), outline=INK)
    d.rectangle((61, 2, 132, 11), fill=(52, 48, 44), outline=BRASS)
    d.text((69, 2), "KINOVA / 12", font=FONT, fill=CREAM)
    im.save(OUT / "hotel_room.png")
    lobby = Image.new("RGBA", (192, 128), INK)
    d = ImageDraw.Draw(lobby)
    d.rectangle((8, 8, 183, 119), fill=(96, 70, 49), outline=BRASS)
    for x in range(12, 182, 16):
        d.line((x, 9, x, 118), fill=(79, 56, 40))
    d.rectangle((8, 20, 40, 74), fill=(73, 52, 40), outline=INK)
    for y in range(26, 72, 8):
        d.line((12, y, 36, y), fill=(120, 88, 60))
    d.rectangle((72, 56, 119, 73), fill=(128, 89, 52), outline=INK)
    d.rectangle((76, 60, 115, 65), fill=CREAM, outline=INK)
    d.rectangle((128, 128, 159, 139), fill=(91, 61, 68), outline=INK)
    d.rectangle((88, 40, 103, 47), fill=(73, 45, 36), outline=BRASS)
    d.rectangle((150, 22, 176, 42), fill=(93, 130, 119), outline=INK)
    d.rectangle((153, 25, 173, 39), outline=(144, 176, 147))
    d.rectangle((88, 114, 103, 127), fill=(164, 117, 65), outline=INK)
    d.rectangle((61, 2, 132, 11), fill=(52, 48, 44), outline=BRASS)
    d.text((69, 2), "KINOVA / LOBBY", font=FONT, fill=CREAM)
    lobby.save(OUT / "hotel_lobby.png")
    sign = Image.new("RGBA", (86, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(sign)
    d.rectangle((0, 0, 85, 15), fill=(47, 34, 28), outline=BRASS)
    d.text((7, 3), "HOTEL KINOVA", font=FONT, fill=(255, 220, 130))
    sign.save(OUT / "hotel_sign.png")
    print("Created Hotel Kinova sign, lobby and room 12")


if __name__ == "__main__":
    main()

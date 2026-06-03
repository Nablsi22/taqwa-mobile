# -*- coding: utf-8 -*-
# Produce a clean 1024x1024 RGB iOS icon master (NO alpha) from the mosque logo,
# composited on a solid domeBlue (#1B4F72) background, logo at 80% safe area.
import os
from PIL import Image

SRC  = r"D:\taqwa-app\taqwa_mobile\assets\images\mosque_logo.png"
OUT  = r"D:\taqwa-app\taqwa_mobile\assets\icons\app_icon_1024.png"
BG   = (0x1B, 0x4F, 0x72)   # domeBlue #1B4F72 -> (27, 79, 114)
SIZE = 1024
SAFE = 0.80                 # logo occupies 80% of the canvas (10% margin each side)

os.makedirs(os.path.dirname(OUT), exist_ok=True)

logo = Image.open(SRC).convert("RGBA")

# Crop to the logo's actual alpha bounding box (strip transparent margins),
# so the visible artwork — not the source padding — is what gets centered.
alpha_bbox = logo.getchannel("A").getbbox()
if alpha_bbox:
    logo = logo.crop(alpha_bbox)

target = int(SIZE * SAFE)
logo.thumbnail((target, target), Image.LANCZOS)   # preserve aspect ratio

canvas = Image.new("RGB", (SIZE, SIZE), BG)        # RGB => no alpha channel
x = (SIZE - logo.width) // 2
y = (SIZE - logo.height) // 2
canvas.paste(logo, (x, y), mask=logo)              # use logo alpha as paste mask
canvas.save(OUT, "PNG")

print("OUT  :", OUT)
print("mode :", canvas.mode)        # must be RGB
print("size :", canvas.size)        # must be (1024, 1024)
print("bg   : #%02X%02X%02X" % BG)

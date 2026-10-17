# -*- coding: utf-8 -*-
"""生成抖数君 iOS app 图标 1024x1024"""
import os
from PIL import Image, ImageDraw, ImageFont

S = 1024
OUT = r'd:\hubulider\dsj\doushujunfull\doushujun-ios\Doushujun\Assets.xcassets\AppIcon.appiconset\AppIcon.png'
os.makedirs(os.path.dirname(OUT), exist_ok=True)

img = Image.new('RGB', (S, S), (15, 23, 42))
d = ImageDraw.Draw(img)
top, bot = (15, 23, 42), (37, 99, 235)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

for cx, cy, r, a in [(200, 180, 260, 26), (870, 820, 340, 22), (760, 140, 140, 18)]:
    ov = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    od = ImageDraw.Draw(ov)
    od.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(147, 197, 253, a))
    img = Image.alpha_composite(img.convert('RGBA'), ov).convert('RGB')

d = ImageDraw.Draw(img)
try:
    f1 = ImageFont.truetype(r'C:\Windows\Fonts\msyhbd.ttc', 430)
except Exception:
    f1 = ImageFont.truetype(r'C:\Windows\Fonts\simhei.ttf', 430)
t = '抖'
bb = d.textbbox((0, 0), t, font=f1)
d.text(((S - (bb[2] - bb[0])) / 2 - bb[0], (S - (bb[3] - bb[1])) / 2 - bb[1]), t, font=f1, fill=(255, 255, 255))
img.save(OUT)
print('icon saved:', OUT, os.path.getsize(OUT), 'bytes')

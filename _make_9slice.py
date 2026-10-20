"""
Script para generar TextBox_9slice.png a partir de TextBox2.1024.png
Ejecutar desde la raíz del proyecto con: python _make_9slice.py
Requiere Pillow: pip install Pillow
"""
from PIL import Image
import os

project_dir = os.path.dirname(os.path.abspath(__file__))
src_path = os.path.join(project_dir, "assets", "resources", "TextBox2.1024.png")
dst_path = os.path.join(project_dir, "assets", "resources", "TextBox_9slice.png")

img = Image.open(src_path).convert("RGBA")
orig_w, orig_h = img.size
print(f"Source: {orig_w}x{orig_h}")

# Measured border thicknesses (pixels in original)
L, R, T, B = 17, 15, 23, 24
FILL = 4  # center fill size

new_w = L + FILL + R   # 36
new_h = T + FILL + B   # 51

new_img = Image.new("RGBA", (new_w, new_h), (0, 0, 0, 0))

cx = orig_w // 2
cy = orig_h // 2

# Corners
new_img.paste(img.crop((0, 0, L, T)),                           (0,      0))
new_img.paste(img.crop((orig_w-R, 0, orig_w, T)),               (L+FILL, 0))
new_img.paste(img.crop((0, orig_h-B, L, orig_h)),               (0,      T+FILL))
new_img.paste(img.crop((orig_w-R, orig_h-B, orig_w, orig_h)),   (L+FILL, T+FILL))

# Edges: take a 1-pixel-wide center slice and stretch it to FILL size
new_img.paste(img.crop((cx, 0, cx+1, T)).resize((FILL, T), Image.NEAREST),             (L, 0))
new_img.paste(img.crop((cx, orig_h-B, cx+1, orig_h)).resize((FILL, B), Image.NEAREST), (L, T+FILL))
new_img.paste(img.crop((0, cy, L, cy+1)).resize((L, FILL), Image.NEAREST),              (0, T))
new_img.paste(img.crop((orig_w-R, cy, orig_w, cy+1)).resize((R, FILL), Image.NEAREST),  (L+FILL, T))

# Center fill (single pixel, tiled)
center_px = img.getpixel((cx, cy))
for py in range(FILL):
    for px in range(FILL):
        new_img.putpixel((L+px, T+py), center_px)

new_img.save(dst_path, "PNG")
print(f"Saved {new_w}x{new_h} minimal 9-slice texture to: {dst_path}")
print("Done!")

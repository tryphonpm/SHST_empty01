"""Analyse la correspondance entre fond_04b.png et les éléments Excalidraw de fond_04.md."""
import lzstring, json, re
from PIL import Image

# --- Dimensions du PNG ---
img = Image.open(r'visuels\fond_04b.png')
print(f"PNG dimensions : {img.width} x {img.height} px")

# --- Lire le JSON Excalidraw ---
with open(r'visuels\fond_04.md', encoding='utf-8') as f:
    content = f.read()
m = re.search(r'```compressed-json\s*([\s\S]+?)```', content)
compressed = m.group(1).replace('\n', '').strip()
lz = lzstring.LZString()
data = json.loads(lz.decompressFromBase64(compressed))

# --- Bounds de TOUS les éléments (rues, bâtiments, positions) ---
xs, ys = [], []
for e in data['elements']:
    if e.get('isDeleted') or e.get('type') == 'text':
        continue
    x, y = e.get('x', 0), e.get('y', 0)
    w, h = e.get('width', 0), e.get('height', 0)
    xs += [x, x + w]
    ys += [y, y + h]

min_x, max_x = min(xs), max(xs)
min_y, max_y = min(ys), max(ys)
ex_w = max_x - min_x
ex_h = max_y - min_y
print(f"Excali ALL bounds : x=[{min_x:.1f}, {max_x:.1f}]  y=[{min_y:.1f}, {max_y:.1f}]")
print(f"Excali ALL size   : {ex_w:.1f} x {ex_h:.1f}")
print(f"Ratio PNG/Excali  : {img.width/ex_w:.4f} x {img.height/ex_h:.4f}")

# --- Bounds des shapes labellisés (X::n) uniquement ---
text_map = {}
for e in data['elements']:
    if e.get('type') == 'text' and e.get('containerId') and not e.get('isDeleted'):
        text_map[e['containerId']] = e.get('text', '').strip()

lxs, lys = [], []
for e in data['elements']:
    if e.get('isDeleted') or e.get('type') == 'text':
        continue
    lbl = text_map.get(e['id'], '')
    if '::' not in lbl:
        continue
    x, y = e.get('x', 0), e.get('y', 0)
    w, h = e.get('width', 0), e.get('height', 0)
    lxs += [x, x + w]
    lys += [y, y + h]

lmin_x, lmax_x = min(lxs), max(lxs)
lmin_y, lmax_y = min(lys), max(lys)
print(f"Excali LABELS only: x=[{lmin_x:.1f}, {lmax_x:.1f}]  y=[{lmin_y:.1f}, {lmax_y:.1f}]")
print(f"Excali LABELS size: {lmax_x - lmin_x:.1f} x {lmax_y - lmin_y:.1f}")

# --- Simulation de compute_transform (labels seulement) ---
VIEWPORT_W, VIEWPORT_H, MARGIN = 1024, 768, 80
shapes_cx = [(lmin_x + lmax_x) / 2]
shapes_cy = [(lmin_y + lmax_y) / 2]
scale = min(
    (VIEWPORT_W - 2 * MARGIN) / (lmax_x - lmin_x),
    (VIEWPORT_H - 2 * MARGIN) / (lmax_y - lmin_y),
)
cx_ex = (lmin_x + lmax_x) / 2
cy_ex = (lmin_y + lmax_y) / 2
offset_x = VIEWPORT_W / 2 - cx_ex * scale
offset_y = VIEWPORT_H / 2 - cy_ex * scale
print(f"\nTransform (labels) : scale={scale:.4f}  offset=({offset_x:.1f}, {offset_y:.1f})")

# --- Rect2 du PNG si appliqué avec le même transform ---
rect_x = round(min_x * scale + offset_x, 1)
rect_y = round(min_y * scale + offset_y, 1)
rect_w = round(ex_w * scale, 1)
rect_h = round(ex_h * scale, 1)
print(f"PNG Rect2 (transform appliqué) : ({rect_x}, {rect_y}, {rect_w}, {rect_h})")
print(f"  → PNG irait de ({rect_x},{rect_y}) à ({rect_x+rect_w:.1f},{rect_y+rect_h:.1f})")

"""Inspecte les types d'éléments et les éléments image dans fond_04.md."""
import lzstring, json, re
from collections import Counter

with open(r'visuels\fond_04.md', encoding='utf-8') as f:
    content = f.read()
m = re.search(r'```compressed-json\s*([\s\S]+?)```', content)
compressed = m.group(1).replace('\n', '').strip()
lz = lzstring.LZString()
data = json.loads(lz.decompressFromBase64(compressed))

print("--- Types d'éléments ---")
types = Counter(e.get('type', '?') for e in data['elements'] if not e.get('isDeleted'))
for t, n in types.items():
    print(f"  {t}: {n}")

print("\n--- Éléments 'image' ---")
found_image = False
for e in data['elements']:
    if e.get('isDeleted'):
        continue
    if e.get('type') == 'image':
        found_image = True
        x = e.get('x', 0)
        y = e.get('y', 0)
        w = e.get('width', 0)
        h = e.get('height', 0)
        fid = str(e.get('fileId', '?'))[:30]
        print(f"  x={x:.1f}  y={y:.1f}  w={w:.1f}  h={h:.1f}  fileId={fid}...")

if not found_image:
    print("  (aucun)")

print("\n--- Éléments non-rectangle / non-text ---")
for e in data['elements']:
    if e.get('isDeleted'):
        continue
    t = e.get('type', '?')
    if t not in ('rectangle', 'text', 'image'):
        x = e.get('x', 0)
        y = e.get('y', 0)
        w = e.get('width', 0)
        h = e.get('height', 0)
        print(f"  {t}: x={x:.1f}  y={y:.1f}  w={w:.1f}  h={h:.1f}")

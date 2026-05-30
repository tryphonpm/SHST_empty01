import lzstring, json, re

with open(r'C:\Users\fbpmo\Documents\GODOT\SHITTY_STREET_empty01\visuels\fond_02.md', encoding='utf-8') as f:
    content = f.read()

m = re.search(r'```compressed-json\s*([\s\S]+?)```', content)
compressed = m.group(1).replace('\n','').strip()
lz = lzstring.LZString()
data = json.loads(lz.decompressFromBase64(compressed))
elements = data['elements']

bg = data.get('appState', {}).get('viewBackgroundColor', '#ffffff')
print('bg:', bg)

shapes = [e for e in elements if not e.get('isDeleted', False)]
print('Total elements:', len(shapes))
for s in shapes:
    t = s['type']
    label = s.get('text', '') if t == 'text' else ''
    x = s['x']
    y = s['y']
    w = s.get('width', 0)
    h = s.get('height', 0)
    bg_color = s.get('backgroundColor', '')
    row = t.ljust(12) + " x=" + str(round(x,1)).rjust(8) + " y=" + str(round(y,1)).rjust(8)
    row += " w=" + str(round(w,1)).rjust(7) + " h=" + str(round(h,1)).rjust(7)
    row += "  text=" + repr(label)[:20] + "  bg=" + str(bg_color)
    print(row)

# Bounding box (non-text)
non_text = [s for s in shapes if s['type'] != 'text']
xs = [s['x'] for s in non_text]
ys = [s['y'] for s in non_text]
xe = [s['x'] + s.get('width', 0) for s in non_text]
ye = [s['y'] + s.get('height', 0) for s in non_text]
print()
print("Bounds: x=" + str(round(min(xs),1)) + " to " + str(round(max(xe),1)) + ", y=" + str(round(min(ys),1)) + " to " + str(round(max(ye),1)))
print("Canvas size: " + str(round(max(xe)-min(xs),1)) + " x " + str(round(max(ye)-min(ys),1)))

# Text bound to shapes (label -> shape id)
text_map = {}
for s in shapes:
    if s['type'] == 'text' and s.get('containerId'):
        text_map[s['containerId']] = s.get('text', '')

print()
print("=== PARCOURS SHAPES (non-text) ===")
for s in non_text:
    sid = s['id']
    label = text_map.get(sid, '?')
    cx = s['x'] + s.get('width', 0) / 2
    cy = s['y'] + s.get('height', 0) / 2
    print("label=" + repr(label).ljust(6) + " type=" + s['type'].ljust(10) + " cx=" + str(round(cx,1)).rjust(8) + " cy=" + str(round(cy,1)).rjust(8) + " w=" + str(round(s.get('width',0),1)) + " h=" + str(round(s.get('height',0),1)))

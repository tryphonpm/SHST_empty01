"""
Génère board_XX.gd, game_XX.tscn et game.gd pour chaque board configuré.
Relancer après toute modification d'un fichier Excalidraw ou des propriétés de cases.

═══════════════════════════════════════════════════════════════
  CONFIGURATION DES BOARDS  ← seule section à éditer
═══════════════════════════════════════════════════════════════
"""
import lzstring, json, re, os

VISUELS_DIR = r'C:\Users\fbpmo\Documents\GODOT\SHITTY_STREET_empty01\visuels'
GODOT_DIR   = r'C:\Users\fbpmo\Documents\GODOT\SHITTY_STREET_empty01\shitty_empty01'
VIEWPORT_W, VIEWPORT_H = 1024, 768
MARGIN = 80

# Valeurs par défaut pour toutes les propriétés de case connues
PROPERTY_DEFAULTS: dict = {
    "bonus": False,
    # ajouter ici les futures propriétés
}

BOARD_CONFIGS = [
    {
        "id":      "02",
        "name":    "Board Classique",
        "md_file": "fond_02.md",
        "bg_color": "#ff1450",
        "case_properties": {
            2:  {"bonus": True},
            5:  {"bonus": True},
            9:  {"bonus": True},
            10: {"bonus": True},
        },
    },
    {
        "id":      "03",
        "name":    "Board Nouveau",
        "md_file": "fond_03.md",
        "bg_color": "#1a3a5c",
        "case_properties": {
            # à compléter selon les règles du board 03
        },
    },
]

# ═══════════════════════════════════════════════════════════════
#  Fonctions utilitaires
# ═══════════════════════════════════════════════════════════════

def decompress_excalidraw(md_path: str) -> dict:
    with open(md_path, encoding='utf-8') as f:
        content = f.read()
    m = re.search(r'```compressed-json\s*([\s\S]+?)```', content)
    compressed = m.group(1).replace('\n', '').strip()
    lz = lzstring.LZString()
    return json.loads(lz.decompressFromBase64(compressed))


def extract_shapes(data: dict) -> list:
    elements = data['elements']
    text_map = {}
    for e in elements:
        if e.get('type') == 'text' and e.get('containerId') and not e.get('isDeleted'):
            text_map[e['containerId']] = e.get('text', '').strip()

    shapes = []
    for e in elements:
        if e.get('isDeleted') or e.get('type') == 'text':
            continue
        label = text_map.get(e['id'], '')
        if label == '':
            continue
        ew, eh = e.get('width', 0), e.get('height', 0)
        shapes.append({
            'label': label,
            'type':  e['type'],
            'cx':    e['x'] + ew / 2,
            'cy':    e['y'] + eh / 2,
            'w':     ew,
            'h':     eh,
        })
    shapes.sort(key=lambda s: int(s['label']) if s['label'].isdigit() else 999)
    return shapes


def compute_transform(shapes: list) -> tuple:
    xs = [s['cx'] for s in shapes]
    ys = [s['cy'] for s in shapes]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    scale = min(
        (VIEWPORT_W - 2 * MARGIN) / (max_x - min_x),
        (VIEWPORT_H - 2 * MARGIN) / (max_y - min_y),
    )
    cx_ex = (min_x + max_x) / 2
    cy_ex = (min_y + max_y) / 2
    offset_x = VIEWPORT_W / 2 - cx_ex * scale
    offset_y = VIEWPORT_H / 2 - cy_ex * scale
    return scale, offset_x, offset_y


def to_godot(cx, cy, scale, offset_x, offset_y):
    return round(cx * scale + offset_x, 1), round(cy * scale + offset_y, 1)


def scale_r(v, scale):
    return round(v * scale / 2, 1)


# ═══════════════════════════════════════════════════════════════
#  Générateur board_XX.gd
# ═══════════════════════════════════════════════════════════════

def generate_board_gd(cfg: dict, shapes: list, pos_dict: dict,
                      scale: float, offset_x: float, offset_y: float) -> str:
    bid       = cfg['id']
    bg        = cfg['bg_color']
    case_props = cfg['case_properties']

    lines = [
        f"## Board {bid} — généré depuis {cfg['md_file']} par generate_scene.py.",
        "## NE PAS ÉDITER MANUELLEMENT.",
        "extends Node2D",
        "",
        f'const BG_COLOR    := Color("{bg}")',
        "const SHAPE_COLOR := Color(1, 1, 1, 1)",
        "const LABEL_COLOR := Color(0, 0, 0, 1)",
        "const LABEL_SIZE  := 20",
        "",
        "## BOARD_DATA — source de vérité de chaque case.",
        "## Chaque dict est extensible ; ajouter de nouvelles clés dans generate_scene.py.",
        "const BOARD_DATA := [",
    ]
    for i in sorted(pos_dict.keys()):
        gx, gy = pos_dict[i][:2]
        props = dict(PROPERTY_DEFAULTS)
        props.update(case_props.get(i, {}))
        bonus_str = "true" if props["bonus"] else "false"
        lines.append(f'\t{{"pos": Vector2({gx}, {gy}), "bonus": {bonus_str}}},\t# {i}')
    lines += [
        "]",
        "",
        "const SHAPES := [",
    ]
    for s in shapes:
        gx, gy = to_godot(s['cx'], s['cy'], scale, offset_x, offset_y)
        rx = scale_r(s['w'], scale)
        ry = scale_r(s['h'], scale)
        lines.append(
            f'\t{{"label": "{s["label"]}", "type": "{s["type"]}", '
            f'"cx": {gx}, "cy": {gy}, "rx": {rx}, "ry": {ry}}},'
        )
    lines += [
        "]",
        "",
        "func _draw() -> void:",
        f"\tdraw_rect(Rect2(0, 0, {VIEWPORT_W}, {VIEWPORT_H}), BG_COLOR)",
        "\tfor sh in SHAPES:",
        '\t\tif sh.type == "ellipse":',
        "\t\t\t_draw_ellipse(Vector2(sh.cx, sh.cy), sh.rx, sh.ry)",
        '\t\telif sh.type == "rectangle":',
        "\t\t\tdraw_rect(Rect2(sh.cx - sh.rx, sh.cy - sh.ry, sh.rx * 2, sh.ry * 2), SHAPE_COLOR)",
        "\tfor sh in SHAPES:",
        "\t\tdraw_string(",
        "\t\t\tThemeDB.fallback_font,",
        "\t\t\tVector2(sh.cx + sh.rx + 4, sh.cy - sh.ry + LABEL_SIZE),",
        "\t\t\tsh.label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL_COLOR",
        "\t\t)",
        "",
        "func _draw_ellipse(center: Vector2, rx: float, ry: float, steps: int = 48) -> void:",
        "\tvar pts: PackedVector2Array",
        "\tfor i in range(steps):",
        "\t\tvar a := TAU * i / steps",
        "\t\tpts.append(center + Vector2(cos(a) * rx, sin(a) * ry))",
        "\tdraw_colored_polygon(pts, SHAPE_COLOR)",
    ]
    return '\n'.join(lines) + '\n'


# ═══════════════════════════════════════════════════════════════
#  Générateur game_XX.tscn
# ═══════════════════════════════════════════════════════════════

def generate_tscn(cfg: dict, pos0x: float, pos0y: float) -> str:
    bid = cfg['id']
    return f"""[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://board_{bid}.gd" id="1_board"]
[ext_resource type="Script" path="res://game.gd" id="2_game"]

[node name="Game{bid}" type="Node2D"]
script = ExtResource("2_game")

[node name="Board" type="Node2D" parent="."]
script = ExtResource("1_board")

[node name="Player" type="Node2D" parent="."]
position = Vector2({pos0x}, {pos0y})

[node name="Triangle" type="Polygon2D" parent="Player"]
color = Color(0.2, 0.41, 1, 1)
polygon = PackedVector2Array(0, -24, -17, 17, 17, 17)

[node name="UI" type="CanvasLayer" parent="."]

[node name="InfoLabel" type="Label" parent="UI"]
offset_left = 16.0
offset_top = 12.0
offset_right = 480.0
offset_bottom = 70.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 20
text = "Case actuelle : 0
Lance le dé (1 à 3) pour avancer."

[node name="DiceLabel" type="Label" parent="UI"]
offset_left = 16.0
offset_top = 80.0
offset_right = 300.0
offset_bottom = 112.0
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 24
text = "Dé : -"

[node name="RollButton" type="Button" parent="UI"]
offset_left = 820.0
offset_top = 16.0
offset_right = 1004.0
offset_bottom = 70.0
text = "Lancer le dé"

[node name="BackButton" type="Button" parent="UI"]
offset_left = 16.0
offset_top = 710.0
offset_right = 180.0
offset_bottom = 755.0
text = "← Menu"

[node name="BonusPopup" type="Panel" parent="UI"]
visible = false
offset_left = 362.0
offset_top = 284.0
offset_right = 662.0
offset_bottom = 484.0

[node name="BonusLabel" type="Label" parent="UI/BonusPopup"]
anchor_left = 0.0
anchor_top = 0.0
anchor_right = 1.0
anchor_bottom = 1.0
theme_override_colors/font_color = Color(1, 0.84, 0, 1)
theme_override_font_sizes/font_size = 64
text = "BONUS"
horizontal_alignment = 1
vertical_alignment = 1
"""


# ═══════════════════════════════════════════════════════════════
#  Générateur game.gd (partagé, une seule fois)
# ═══════════════════════════════════════════════════════════════

GAME_GD = """\
## Logique de jeu partagée entre tous les boards.
## Chaque scène game_XX.tscn utilise ce script.
extends Node2D

const BONUS_DISPLAY_DURATION: float = 2.0
const MENU_SCENE: String = "res://menu.tscn"

var steps_to_finish: int = 0
var progress: int = 0
var is_moving: bool = false
var game_over: bool = false

@onready var board: Node2D       = $Board
@onready var player: Node2D      = $Player
@onready var info_label: Label   = $UI/InfoLabel
@onready var dice_label: Label   = $UI/DiceLabel
@onready var roll_button: Button = $UI/RollButton
@onready var back_button: Button = $UI/BackButton
@onready var bonus_popup: Panel  = $UI/BonusPopup

func _ready() -> void:
\trandomize()
\tsteps_to_finish = board.BOARD_DATA.size()
\tplayer.position = board.BOARD_DATA[0]["pos"]
\troll_button.pressed.connect(_on_roll_pressed)
\tback_button.pressed.connect(_on_back_pressed)
\tbonus_popup.visible = false
\t_update_ui()

func _on_roll_pressed() -> void:
\tif is_moving or game_over:
\t\treturn
\tvar roll: int = randi_range(1, 3)
\tdice_label.text = "Dé : %d" % roll
\t_advance(roll)

func _on_back_pressed() -> void:
\tget_tree().change_scene_to_file(MENU_SCENE)

func _advance(steps: int) -> void:
\tis_moving = true
\troll_button.disabled = true

\tfor i in range(steps):
\t\tif progress >= steps_to_finish:
\t\t\tbreak
\t\tprogress += 1
\t\tvar idx: int = progress % board.BOARD_DATA.size()
\t\tvar target: Vector2 = board.BOARD_DATA[idx]["pos"]

\t\tvar tween: Tween = create_tween()
\t\ttween.tween_property(player, "position", target, 0.25) \\
\t\t\t.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
\t\tawait tween.finished

\t\t_update_ui()

\t\t# Popup bonus uniquement sur la case finale du lancer
\t\tif i == steps - 1 and board.BOARD_DATA[idx]["bonus"]:
\t\t\tawait _show_bonus_popup()

\tis_moving = false

\tif progress >= steps_to_finish:
\t\t_end_game()
\telse:
\t\troll_button.disabled = false

func _show_bonus_popup() -> void:
\tbonus_popup.visible = true
\tawait get_tree().create_timer(BONUS_DISPLAY_DURATION).timeout
\tbonus_popup.visible = false

func _end_game() -> void:
\tgame_over = true
\troll_button.disabled = true
\tinfo_label.text = "Bravo ! Tu as rejoint le départ (0).\\nPartie terminée."

func _update_ui() -> void:
\tif game_over:
\t\treturn
\tvar current_case: int = progress % board.BOARD_DATA.size()
\tif progress >= steps_to_finish:
\t\tcurrent_case = 0
\tinfo_label.text = "Case actuelle : %d\\nLance le dé (1 à 3) pour avancer." % current_case
"""


# ═══════════════════════════════════════════════════════════════
#  Boucle principale
# ═══════════════════════════════════════════════════════════════

board_registry = []   # [(id, name, scene_path), ...] pour le menu

for cfg in BOARD_CONFIGS:
    md_path = os.path.join(VISUELS_DIR, cfg['md_file'])
    print(f"\n══ Board {cfg['id']} — {cfg['name']} ({cfg['md_file']}) ══")

    data   = decompress_excalidraw(md_path)
    shapes = extract_shapes(data)
    scale, offset_x, offset_y = compute_transform(shapes)

    pos_dict = {}
    for s in shapes:
        gx, gy = to_godot(s['cx'], s['cy'], scale, offset_x, offset_y)
        try:
            idx = int(s['label'])
            pos_dict[idx] = (gx, gy, s['type'], s['w'], s['h'])
        except ValueError:
            pass

    for i in sorted(pos_dict.keys()):
        gx, gy = pos_dict[i][:2]
        bonus = cfg['case_properties'].get(i, {}).get('bonus', False)
        print(f"  [{i:>2}]  cx={gx:7}  cy={gy:7}  bonus={bonus}")

    # board_XX.gd
    board_gd = generate_board_gd(cfg, shapes, pos_dict, scale, offset_x, offset_y)
    board_path = os.path.join(GODOT_DIR, f"board_{cfg['id']}.gd")
    with open(board_path, 'w', encoding='utf-8') as f:
        f.write(board_gd)
    print(f"  → {board_path}")

    # game_XX.tscn
    p0x, p0y = pos_dict[0][:2]
    tscn = generate_tscn(cfg, p0x, p0y)
    tscn_path = os.path.join(GODOT_DIR, f"game_{cfg['id']}.tscn")
    with open(tscn_path, 'w', encoding='utf-8') as f:
        f.write(tscn)
    print(f"  → {tscn_path}")

    board_registry.append((cfg['id'], cfg['name'], f"res://game_{cfg['id']}.tscn"))

# game.gd (partagé)
game_gd_path = os.path.join(GODOT_DIR, 'game.gd')
with open(game_gd_path, 'w', encoding='utf-8') as f:
    f.write(GAME_GD)
print(f"\n  → {game_gd_path}")

# Exporter la liste des boards pour menu.gd (affichage)
print("\n══ Boards disponibles pour le menu ══")
for bid, bname, bscene in board_registry:
    print(f"  Board {bid} : \"{bname}\"  →  {bscene}")

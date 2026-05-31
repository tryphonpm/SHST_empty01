"""
Génère board_XX.gd et game_XX.tscn pour chaque board configuré.
Relancer après toute modification d'un fichier Excalidraw ou des propriétés de cases.

═══════════════════════════════════════════════════════════════
  CONFIGURATION DES BOARDS  ← seule section à éditer
═══════════════════════════════════════════════════════════════

board_type "classic" :
  - Labels = entiers (0, 1, 2, …)
  - BOARD_DATA = Array de dictionnaires, indexé par position
  - Parcours = circulaire +1, retour à 0 = fin
  - Script de jeu : game.gd

board_type "urban" :
  - Labels = chaînes "X::n" (ex. "B::1", "&::2", "@::3")
  - BOARD_DATA = Dictionary keyed par label
  - Parcours = liste explicite de labels (définie dans BOARD_CONFIGS)
  - Fin = atteindre ou dépasser le dernier label du PARCOURS
  - Script de jeu : game_urban.gd
"""
import lzstring, json, re, os, struct

VISUELS_DIR = r'C:\Users\fbpmo\Documents\GODOT\SHITTY_STREET_empty01\visuels'
GODOT_DIR   = r'C:\Users\fbpmo\Documents\GODOT\SHITTY_STREET_empty01\shitty_empty01'
VIEWPORT_W, VIEWPORT_H = 1024, 768
MARGIN = 80

# Valeurs par défaut pour toutes les propriétés de case (boards classic)
PROPERTY_DEFAULTS: dict = {
    "bonus": False,
    "forks": [],
}

BOARD_CONFIGS = [
    {
        "id":         "02",
        "name":       "Board Classique",
        "md_file":    "fond_02.md",
        "board_type": "classic",
        "bg_color":   "#ff1450",
        "case_properties": {
            2:  {"bonus": True},
            5:  {"bonus": True},
            9:  {"bonus": True},
            10: {"bonus": True},
        },
    },
    {
        "id":         "03",
        "name":       "Board Nouveau",
        "md_file":    "fond_03.md",
        "board_type": "classic",
        "bg_color":   "#1a3a5c",
        "case_properties": {
            5: {"forks": [6, 11]},   # carrefour : circuit extérieur (6) ou intérieur (11)
        },
    },
    {
        "id":         "04",
        "name":       "Quartier Citadin",
        "md_file":    "fond_04.md",     # à créer dans Obsidian/Excalidraw
        "board_type": "urban",
        "bg_color":   "#1c2b0e",
        "bg_image":   "fond_04b.png",   # image de fond (res://visuels/fond_04b.png)
        # Label de départ. Doit être le premier élément de "parcours".
        "start_label": "B::1",
        # Séquence ordonnée des emplacements à parcourir (décision game-design).
        # Excalidraw fournit les positions ; ici on définit l'ordre et le chemin.
        "parcours": [
            "B::1",  "B::3",  "B::5",  "B::7",  "B::9",  "B::11",
            "&::2",  "@::2",  "&::3",
            "B::13", "B::15", "B::17", "B::19",
        ],
        # Propriétés spécifiques par label.
        # type "fork" est inféré automatiquement du préfixe "&" dans le label.
        # "forks" : labels offerts en choix au joueur à ce carrefour.
        "label_properties": {
            "&::1": {"forks": ["C::1", "B::13", "A::13"]},
            "&::2": {"forks": ["C::1", "B::13", "A::13"]},
            "&::3": {"forks": ["C::1", "B::13", "A::13"]},
        },
        # Source unifiée des données board (rues, sidewalks, positions, forks).
        # Remplace les anciens streets_json et BOARD_DATA générés depuis Excalidraw.
        "boards_setup_json": "tmp/BOARDS_SETUP.json",
        # Données des joueurs : état initial, lu depuis le JSON.
        "players_json": "tmp/players.json",
    },
]


# ═══════════════════════════════════════════════════════════════
#  Fonctions utilitaires communes
# ═══════════════════════════════════════════════════════════════

def get_png_dimensions(path: str) -> tuple:
    """Lit la largeur et la hauteur d'un PNG depuis son en-tête (sans dépendance externe)."""
    with open(path, 'rb') as f:
        f.read(8)   # signature PNG
        f.read(4)   # longueur du chunk IHDR
        f.read(4)   # b'IHDR'
        w = struct.unpack('>I', f.read(4))[0]
        h = struct.unpack('>I', f.read(4))[0]
    return w, h


def get_all_elements_bounds(data: dict) -> tuple:
    """
    Retourne (min_x, min_y, max_x, max_y) pour TOUS les éléments non supprimés
    (incluant formes non-labellisées comme les rues et bâtiments).
    """
    xs, ys = [], []
    for e in data['elements']:
        if e.get('isDeleted') or e.get('type') == 'text':
            continue
        x, y = e.get('x', 0), e.get('y', 0)
        w, h = e.get('width', 0), e.get('height', 0)
        xs += [x, x + w]
        ys += [y, y + h]
    if not xs:
        return (0, 0, 1, 1)
    return min(xs), min(ys), max(xs), max(ys)


def compute_bg_rect(png_path: str, data: dict,
                    scale: float, offset_x: float, offset_y: float) -> tuple | None:
    """
    Calcule le Rect2 Godot (x, y, w, h) pour placer une image PNG de fond
    en alignement parfait avec les éléments Excalidraw.

    Méthode 1 (prioritaire) — élément image présent dans Excalidraw :
      L'utilisateur a importé le PNG comme background dans Excalidraw.
      Sa position (x, y, w, h) dans l'espace Excalidraw est connue exactement.
      On applique le même transform que les shapes → alignement parfait garanti.

    Méthode 2 (fallback) — estimation par padding :
      Hypothèse zoom=1x (1 unité Excalidraw = 1 pixel PNG).
      Le padding est estimé à partir des bounds de tous les éléments.

    Retourne None si le fichier PNG est introuvable (méthode 2 uniquement).
    """
    # ── Méthode 1 : élément image Excalidraw ─────────────────────────────────
    for e in data['elements']:
        if e.get('isDeleted') or e.get('type') != 'image':
            continue
        ex = e.get('x', 0)
        ey = e.get('y', 0)
        ew = e.get('width', 0)
        eh = e.get('height', 0)
        rect_x = round(ex * scale + offset_x, 1)
        rect_y = round(ey * scale + offset_y, 1)
        rect_w = round(ew * scale, 1)
        rect_h = round(eh * scale, 1)
        print(f"  [bg_image] Élément image Excalidraw : "
              f"x={ex:.1f} y={ey:.1f} w={ew:.1f} h={eh:.1f}")
        print(f"             → Godot Rect2({rect_x}, {rect_y}, {rect_w}, {rect_h})")
        return (rect_x, rect_y, rect_w, rect_h)

    # ── Méthode 2 : fallback estimation padding ───────────────────────────────
    if not os.path.exists(png_path):
        return None
    png_w, png_h = get_png_dimensions(png_path)
    all_min_x, all_min_y, all_max_x, all_max_y = get_all_elements_bounds(data)
    all_w = all_max_x - all_min_x
    all_h = all_max_y - all_min_y
    pad_x = (png_w - all_w) / 2.0
    pad_y = (png_h - all_h) / 2.0
    png_ex_min_x = all_min_x - pad_x
    png_ex_min_y = all_min_y - pad_y
    rect_x = round(png_ex_min_x * scale + offset_x, 1)
    rect_y = round(png_ex_min_y * scale + offset_y, 1)
    rect_w = round(png_w * scale, 1)
    rect_h = round(png_h * scale, 1)
    print(f"  [bg_image] Estimation padding (zoom=1x) : "
          f"PNG {png_w}×{png_h}px → Godot Rect2({rect_x}, {rect_y}, {rect_w}, {rect_h})")
    return (rect_x, rect_y, rect_w, rect_h)

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
    # Classic boards : tri par numéro de label entier.
    # Urban boards : labels non-entiers passent à la fin (999) — l'ordre est géré par PARCOURS.
    shapes.sort(key=lambda s: int(s['label']) if s['label'].isdigit() else 999)
    return shapes


def compute_transform(shapes: list) -> tuple:
    xs = [s['cx'] for s in shapes]
    ys = [s['cy'] for s in shapes]
    min_x, max_x = min(xs), max(xs)
    min_y, max_y = min(ys), max(ys)
    scale = min(
        (VIEWPORT_W - 2 * MARGIN) / max(max_x - min_x, 1),
        (VIEWPORT_H - 2 * MARGIN) / max(max_y - min_y, 1),
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
#  Urban : helpers
# ═══════════════════════════════════════════════════════════════

def parse_urban_label(label: str) -> tuple:
    """
    Analyse un label au format 'X::n'.
    Retourne (etype, street, num).
      etype : 'passage' si '@', 'fork' si '&', 'address' sinon.
    """
    if '::' not in label:
        return ('unknown', label, 0)
    street, _, tail = label.partition('::')
    try:
        num = int(tail)
    except ValueError:
        num = 0
    if street == '@':
        etype = 'passage'
    elif street == '&':
        etype = 'fork'
    else:
        etype = 'address'
    return (etype, street, num)


# ═══════════════════════════════════════════════════════════════
#  Générateur board_XX.gd — Classic
# ═══════════════════════════════════════════════════════════════

def generate_board_gd_classic(cfg: dict, shapes: list, pos_dict: dict,
                               scale: float, offset_x: float, offset_y: float) -> str:
    bid        = cfg['id']
    bg         = cfg['bg_color']
    case_props = cfg.get('case_properties', {})

    lines = [
        f"## Board {bid} — généré depuis {cfg['md_file']} par generate_scene.py.",
        "## NE PAS ÉDITER MANUELLEMENT.",
        "extends Node2D",
        "",
        'const BOARD_TYPE   := "classic"',
        "",
        f'const BG_COLOR    := Color("{bg}")',
        "const SHAPE_COLOR := Color(1, 1, 1, 1)",
        "const LABEL_COLOR := Color(0, 0, 0, 1)",
        "const LABEL_SIZE  := 20",
        "",
        "## Couleurs dynamiques par label de case (peuplées en phase de setup).",
        "var shape_colors: Dictionary = {}",
        "",
        "func set_shape_color(label: String, color: Color) -> void:",
        "\tshape_colors[label] = color",
        "\tqueue_redraw()",
        "",
        "## BOARD_DATA — source de vérité de chaque case.",
        "const BOARD_DATA := [",
    ]
    for i in sorted(pos_dict.keys()):
        gx, gy = pos_dict[i][:2]
        props = dict(PROPERTY_DEFAULTS)
        props.update(case_props.get(i, {}))
        bonus_str = "true" if props["bonus"] else "false"
        forks_str = str(props["forks"])
        lines.append(
            f'\t{{"pos": Vector2({gx}, {gy}), "bonus": {bonus_str}, "forks": {forks_str}}},\t# {i}'
        )
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
        "\t\tvar color: Color = shape_colors.get(sh.label, SHAPE_COLOR)",
        '\t\tif sh.type == "ellipse":',
        "\t\t\t_draw_ellipse(Vector2(sh.cx, sh.cy), sh.rx, sh.ry, color)",
        '\t\telif sh.type == "rectangle":',
        "\t\t\tdraw_rect(Rect2(sh.cx - sh.rx, sh.cy - sh.ry, sh.rx * 2, sh.ry * 2), color)",
        "\tfor sh in SHAPES:",
        "\t\tdraw_string(",
        "\t\t\tThemeDB.fallback_font,",
        "\t\t\tVector2(sh.cx + sh.rx + 4, sh.cy - sh.ry + LABEL_SIZE),",
        "\t\t\tsh.label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL_COLOR",
        "\t\t)",
        "",
        "func _draw_ellipse(center: Vector2, rx: float, ry: float,",
        "\t\t\tcolor: Color = SHAPE_COLOR, steps: int = 48) -> void:",
        "\tvar pts: PackedVector2Array",
        "\tfor i in range(steps):",
        "\t\tvar a := TAU * i / steps",
        "\t\tpts.append(center + Vector2(cos(a) * rx, sin(a) * ry))",
        "\tdraw_colored_polygon(pts, color)",
    ]
    return '\n'.join(lines) + '\n'


# ═══════════════════════════════════════════════════════════════
#  Générateur board_XX.gd — Urban
# ═══════════════════════════════════════════════════════════════

def _to_gd(value, indent: int = 0) -> str:
    """Convertit récursivement une valeur Python (dict/list/str/int/float/bool)
    en littéral GDScript indenté."""
    tab = '\t' * indent
    inner = '\t' * (indent + 1)
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if isinstance(value, str):
        return f'"{value}"'
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        if not value:
            return '[]'
        items = ', '.join(_to_gd(v) for v in value)
        return f'[{items}]'
    if isinstance(value, dict):
        if not value:
            return '{}'
        lines = ['{']
        for k, v in value.items():
            lines.append(f'{inner}"{k}": {_to_gd(v, indent + 1)},')
        lines.append(tab + '}')
        return '\n'.join(lines)
    return str(value)


def _to_gd_board_setup(value, indent: int = 0, _key: str = '') -> str:
    """Comme _to_gd, mais convertit spécialement les positions :
    - "pos": [x, y]  →  Vector2(x, y)
    - "pos": null    →  Vector2.ZERO
    """
    tab = '\t' * indent
    inner = '\t' * (indent + 1)
    if _key == 'pos':
        if value is None:
            return 'Vector2.ZERO'
        if isinstance(value, list) and len(value) == 2:
            return f'Vector2({value[0]}, {value[1]})'
    if isinstance(value, bool):
        return 'true' if value else 'false'
    if value is None:
        return '""'
    if isinstance(value, str):
        return f'"{value}"'
    if isinstance(value, (int, float)):
        return str(value)
    if isinstance(value, list):
        if not value:
            return '[]'
        items = ', '.join(_to_gd_board_setup(v) for v in value)
        return f'[{items}]'
    if isinstance(value, dict):
        if not value:
            return '{}'
        lines = ['{']
        for k, v in value.items():
            lines.append(f'{inner}"{k}": {_to_gd_board_setup(v, indent + 1, _key=k)},')
        lines.append(tab + '}')
        return '\n'.join(lines)
    return str(value)


def generate_board_gd_urban(cfg: dict, shapes: list, label_dict: dict,
                             scale: float, offset_x: float, offset_y: float,
                             bg_rect: tuple | None = None,
                             board_setup_data: dict | None = None) -> str:
    bid         = cfg['id']
    bg          = cfg['bg_color']
    bg_image    = cfg.get('bg_image', '')
    start_label = cfg['start_label']
    parcours    = cfg['parcours']

    # Bloc image de fond (optionnel)
    if bg_image and bg_rect is not None:
        bg_image_path = f"res://visuels/{bg_image}"
        rx, ry, rw, rh = bg_rect
        bg_lines = [
            f'const BG_TEXTURE: Texture2D = preload("{bg_image_path}")',
            f"## Position de l'image de fond alignée sur l'espace Excalidraw (calculée automatiquement).",
            f"const BG_RECT := Rect2({rx}, {ry}, {rw}, {rh})",
        ]
        draw_bg_line_1 = f"\tdraw_rect(Rect2(0, 0, {VIEWPORT_W}, {VIEWPORT_H}), BG_COLOR)"
        draw_bg_line_2 = "\tdraw_texture_rect(BG_TEXTURE, BG_RECT, false)"
        draw_bg_lines  = [draw_bg_line_1, draw_bg_line_2]
    elif bg_image:
        bg_image_path = f"res://visuels/{bg_image}"
        bg_lines = [f'const BG_TEXTURE: Texture2D = preload("{bg_image_path}")']
        draw_bg_lines = [
            f"\tdraw_rect(Rect2(0, 0, {VIEWPORT_W}, {VIEWPORT_H}), BG_COLOR)",
            f"\tdraw_texture_rect(BG_TEXTURE, Rect2(0, 0, {VIEWPORT_W}, {VIEWPORT_H}), false)",
        ]
    else:
        bg_lines      = []
        draw_bg_lines = [f"\tdraw_rect(Rect2(0, 0, {VIEWPORT_W}, {VIEWPORT_H}), BG_COLOR)"]

    lines = [
        f"## Board {bid} — généré depuis {cfg['md_file']} par generate_scene.py.",
        "## NE PAS ÉDITER MANUELLEMENT.",
        "## BoardBase expose BOARD_SETUP dans l'inspecteur (inspector_streets).",
        "extends BoardBase",
        "",
        'const BOARD_TYPE  := "urban"',
        f'const START_LABEL := "{start_label}"',
        "",
        f'const BG_COLOR    := Color("{bg}")',
        "const LABEL_COLOR := Color(1, 1, 1, 1)",
        "const LABEL_SIZE  := 10",
        "## Largeur de la zone de dessin du label, centrée sur le point central de l'emplacement.",
        "## Doit être assez large pour le label le plus long (ex. 'B::20' = 5 chars).",
        "const LABEL_WIDTH := 52.0",
    ] + ([""] + bg_lines if bg_lines else []) + [
        "",
        "## Couleurs dynamiques par label (peuplées en phase de setup).",
        "## Affecte la couleur du texte du label (les formes ne sont pas dessinées).",
        "var shape_colors: Dictionary = {}",

        "",
        "func set_shape_color(label: String, color: Color) -> void:",
        "\tshape_colors[label] = color",
        "\tqueue_redraw()",
    ]

    # Bloc BOARD_SETUP — source unifiée (streets, sidewalks, positions, directions)
    if board_setup_data:
        lines += [
            "",
            "## BOARD_SETUP — source unifiée des données du board.",
            "## Générée depuis tmp/BOARDS_SETUP.json (boards_setup_json dans BOARD_CONFIGS).",
            "## Remplace les anciennes const BOARD_DATA et STREETS.",
            "## Structure : streets → rue → sidewalk → label → {type, pos, directions?}",
            f"const BOARD_SETUP: Dictionary = {_to_gd_board_setup(board_setup_data)}",
        ]

    # Bloc PLAYERS (optionnel — présent si players_data fourni)
    players_data = cfg.get('_players_data')
    if players_data:
        lines += [
            "",
            "## PLAYERS — état initial des joueurs (position de départ, domicile, couleur).",
            "## Source : players_json défini dans BOARD_CONFIGS.",
            "## game_urban.gd en fait une copie mutable (var players) mise à jour à chaque tour.",
            f"const PLAYERS: Dictionary = {_to_gd(players_data)}",
        ]

    lines += [
        "",
        "const SHAPES := [",
    ]
    for s in shapes:
        if '::' not in s['label']:
            continue
        gx, gy = to_godot(s['cx'], s['cy'], scale, offset_x, offset_y)
        lines.append(
            f'\t{{"label": "{s["label"]}", "type": "{s["type"]}", '
            f'"cx": {gx}, "cy": {gy}}},'
        )
    lines += [
        "]",
        "",
        "func _draw() -> void:",
    ] + draw_bg_lines + [
        "\t# Les rectangles Excalidraw ne sont PAS dessinés (emplacements transparents).",
        "\t# Seuls les labels sont affichés, centrés sur le point central de chaque emplacement.",
        "\t# shape_colors permet de personnaliser la couleur d'un label individuel (via setup).",
        "\tfor sh in SHAPES:",
        "\t\tvar color: Color = shape_colors.get(sh.label, LABEL_COLOR)",
        "\t\tdraw_string(",
        "\t\t\tThemeDB.fallback_font,",
        "\t\t\tVector2(sh.cx - LABEL_WIDTH * 0.5, sh.cy + LABEL_SIZE * 0.5),",
        "\t\t\tsh.label, HORIZONTAL_ALIGNMENT_CENTER, LABEL_WIDTH, LABEL_SIZE, color",
        "\t\t)",
    ]
    return '\n'.join(lines) + '\n'


# ═══════════════════════════════════════════════════════════════
#  Générateur game_XX.tscn
# ═══════════════════════════════════════════════════════════════

def generate_tscn(cfg: dict, pos0x: float, pos0y: float,
                  board_type: str = 'classic') -> str:
    bid         = cfg['id']
    game_script = "game_urban.gd" if board_type == 'urban' else "game.gd"

    info_text = (
        "Adresse : B::1  (1/13)\\nLance le dé (1 à 3) pour avancer."
        if board_type == 'urban'
        else "Case actuelle : 0\\nLance le dé (1 à 3) pour avancer."
    )

    player_script_entry = (
        '\n[ext_resource type="Script" path="res://player.gd" id="3_player"]'
        if board_type == 'urban' else ''
    )
    player_script_line = (
        '\nscript = ExtResource("3_player")'
        if board_type == 'urban' else ''
    )
    load_steps = 4 if board_type == 'urban' else 3

    return f"""[gd_scene load_steps={load_steps} format=3]

[ext_resource type="Script" path="res://board_{bid}.gd" id="1_board"]
[ext_resource type="Script" path="res://{game_script}" id="2_game"]{player_script_entry}

[node name="Game{bid}" type="Node2D"]
script = ExtResource("2_game")

[node name="Board" type="Node2D" parent="."]
script = ExtResource("1_board")

[node name="Player" type="Node2D" parent="."]
position = Vector2({pos0x}, {pos0y}){player_script_line}

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
text = "{info_text}"

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

[node name="ForkPopup" type="Panel" parent="UI"]
visible = false
offset_left = 312.0
offset_top = 254.0
offset_right = 712.0
offset_bottom = 514.0

[node name="VBox" type="VBoxContainer" parent="UI/ForkPopup"]
anchor_left = 0.0
anchor_top = 0.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 16.0
offset_top = 16.0
offset_right = -16.0
offset_bottom = -16.0
theme_override_constants/separation = 20

[node name="Title" type="Label" parent="UI/ForkPopup/VBox"]
layout_mode = 2
theme_override_colors/font_color = Color(1, 1, 1, 1)
theme_override_font_sizes/font_size = 22
text = "Choisissez votre direction :"
horizontal_alignment = 1

[node name="ButtonContainer" type="VBoxContainer" parent="UI/ForkPopup/VBox"]
layout_mode = 2
theme_override_constants/separation = 12
"""


# ═══════════════════════════════════════════════════════════════
#  Boucle principale
# ═══════════════════════════════════════════════════════════════

board_registry = []   # [(id, name, scene_path), ...] pour le menu

for cfg in BOARD_CONFIGS:
    md_path    = os.path.join(VISUELS_DIR, cfg['md_file'])
    board_type = cfg.get('board_type', 'classic')

    print(f"\n══ Board {cfg['id']} — {cfg['name']} ({cfg['md_file']}) [{board_type}] ══")

    if not os.path.exists(md_path):
        print(f"  [!] Fichier manquant : {md_path}")
        print(f"      Board {cfg['id']} ignoré — créer le dessin dans Obsidian/Excalidraw.")
        continue

    data   = decompress_excalidraw(md_path)
    shapes = extract_shapes(data)
    scale, offset_x, offset_y = compute_transform(shapes)

    # ── Classic ──────────────────────────────────────────────────────────────
    if board_type == 'classic':
        pos_dict = {}
        for s in shapes:
            gx, gy = to_godot(s['cx'], s['cy'], scale, offset_x, offset_y)
            try:
                idx = int(s['label'])
                pos_dict[idx] = (gx, gy, s['type'], s['w'], s['h'])
            except ValueError:
                pass

        case_props = cfg.get('case_properties', {})
        for i in sorted(pos_dict.keys()):
            gx, gy = pos_dict[i][:2]
            cprops = case_props.get(i, {})
            bonus  = cprops.get('bonus', False)
            forks  = cprops.get('forks', [])
            info   = []
            if bonus: info.append("bonus")
            if forks: info.append(f"forks→{forks}")
            tag = ("  [" + ", ".join(info) + "]") if info else ""
            print(f"  [{i:>2}]  cx={gx:7}  cy={gy:7}{tag}")

        board_gd   = generate_board_gd_classic(cfg, shapes, pos_dict, scale, offset_x, offset_y)
        board_path = os.path.join(GODOT_DIR, f"board_{cfg['id']}.gd")
        with open(board_path, 'w', encoding='utf-8') as f:
            f.write(board_gd)
        print(f"  → {board_path}")

        p0x, p0y = pos_dict[0][:2]
        tscn      = generate_tscn(cfg, p0x, p0y, board_type='classic')
        tscn_path = os.path.join(GODOT_DIR, f"game_{cfg['id']}.tscn")
        with open(tscn_path, 'w', encoding='utf-8') as f:
            f.write(tscn)
        print(f"  → {tscn_path}")

        board_registry.append((cfg['id'], cfg['name'], f"res://game_{cfg['id']}.tscn"))

    # ── Urban ─────────────────────────────────────────────────────────────────
    elif board_type == 'urban':
        label_dict  = {}
        label_props = cfg.get('label_properties', {})

        for s in shapes:
            label = s['label']
            if '::' not in label:
                continue   # ignorer les formes sans label au format urban
            gx, gy = to_godot(s['cx'], s['cy'], scale, offset_x, offset_y)
            etype, street, num = parse_urban_label(label)
            label_dict[label] = {
                'gx': gx, 'gy': gy,
                'etype': etype, 'street': street, 'num': num,
            }

        for label in sorted(label_dict.keys()):
            linfo  = label_dict[label]
            lp     = label_props.get(label, {})
            forks  = lp.get('forks', [])
            etype  = linfo['etype']
            tags   = []
            if forks: tags.append(f"forks→{forks}")
            tag = ("  [" + ", ".join(tags) + "]") if tags else ""
            print(f"  [{label:>10}]  cx={linfo['gx']:7}  cy={linfo['gy']:7}  type={etype}{tag}")

        # Calcul du Rect2 de l'image de fond (si définie)
        bg_image = cfg.get('bg_image', '')
        bg_rect  = None
        if bg_image:
            png_path = os.path.join(GODOT_DIR, 'visuels', bg_image)
            bg_rect  = compute_bg_rect(png_path, data, scale, offset_x, offset_y)

        PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))

        # Chargement BOARDS_SETUP.json — source unifiée streets/sidewalks/positions
        board_setup_data = None
        boards_setup_rel = cfg.get('boards_setup_json', '')
        if boards_setup_rel:
            boards_setup_path = os.path.join(PROJECT_DIR, boards_setup_rel)
            if os.path.exists(boards_setup_path):
                with open(boards_setup_path, 'r', encoding='utf-8') as f:
                    all_setups = json.load(f)
                board_key = f"board_{cfg['id']}"
                board_setup_data = all_setups.get(board_key)
                if board_setup_data:
                    print(f"  [board_setup] Chargé : {boards_setup_path} ({board_key})")
                else:
                    print(f"  [board_setup] Clé '{board_key}' introuvable dans {boards_setup_path}")
            else:
                print(f"  [board_setup] Fichier introuvable : {boards_setup_path}")

        # Chargement des données joueurs (players_json, optionnel)
        players_data = None
        players_json_rel = cfg.get('players_json', '')
        if players_json_rel:
            players_json_path = os.path.join(PROJECT_DIR, players_json_rel)
            if os.path.exists(players_json_path):
                with open(players_json_path, 'r', encoding='utf-8') as f:
                    players_data = json.load(f)
                print(f"  [players] Chargé : {players_json_path}")
            else:
                print(f"  [players] Fichier introuvable : {players_json_path}")
        cfg['_players_data'] = players_data

        board_gd   = generate_board_gd_urban(cfg, shapes, label_dict, scale, offset_x, offset_y,
                                              bg_rect=bg_rect, board_setup_data=board_setup_data)
        board_path = os.path.join(GODOT_DIR, f"board_{cfg['id']}.gd")
        with open(board_path, 'w', encoding='utf-8') as f:
            f.write(board_gd)
        print(f"  → {board_path}")

        start_label = cfg['start_label']
        if start_label in label_dict:
            p0x = label_dict[start_label]['gx']
            p0y = label_dict[start_label]['gy']
        else:
            p0x, p0y = VIEWPORT_W / 2, VIEWPORT_H / 2

        tscn      = generate_tscn(cfg, p0x, p0y, board_type='urban')
        tscn_path = os.path.join(GODOT_DIR, f"game_{cfg['id']}.tscn")
        with open(tscn_path, 'w', encoding='utf-8') as f:
            f.write(tscn)
        print(f"  → {tscn_path}")

        board_registry.append((cfg['id'], cfg['name'], f"res://game_{cfg['id']}.tscn"))

    else:
        print(f"  [!] board_type inconnu : '{board_type}' — board ignoré.")

# Exporter la liste des boards pour menu.gd (affichage)
print("\n══ Boards disponibles pour le menu ══")
for bid, bname, bscene in board_registry:
    print(f"  Board {bid} : \"{bname}\"  →  {bscene}")

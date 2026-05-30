## Board 02 — généré depuis fond_02.md par generate_scene.py.
## NE PAS ÉDITER MANUELLEMENT.
extends Node2D

const BOARD_TYPE   := "classic"

const BG_COLOR    := Color("#ff1450")
const SHAPE_COLOR := Color(1, 1, 1, 1)
const LABEL_COLOR := Color(0, 0, 0, 1)
const LABEL_SIZE  := 20

## Couleurs dynamiques par label de case (peuplées en phase de setup).
var shape_colors: Dictionary = {}

func set_shape_color(label: String, color: Color) -> void:
	shape_colors[label] = color
	queue_redraw()

## BOARD_DATA — source de vérité de chaque case.
const BOARD_DATA := [
	{"pos": Vector2(109.8, 546.8), "bonus": false, "forks": []},	# 0
	{"pos": Vector2(145.4, 396.2), "bonus": false, "forks": []},	# 1
	{"pos": Vector2(222.3, 200.5), "bonus": true, "forks": []},	# 2
	{"pos": Vector2(415.7, 80.0), "bonus": false, "forks": []},	# 3
	{"pos": Vector2(599.6, 80.0), "bonus": false, "forks": []},	# 4
	{"pos": Vector2(735.9, 149.7), "bonus": true, "forks": []},	# 5
	{"pos": Vector2(594.0, 270.2), "bonus": false, "forks": []},	# 6
	{"pos": Vector2(636.8, 401.0), "bonus": false, "forks": []},	# 7
	{"pos": Vector2(797.7, 407.3), "bonus": false, "forks": []},	# 8
	{"pos": Vector2(914.2, 557.1), "bonus": true, "forks": []},	# 9
	{"pos": Vector2(807.2, 665.7), "bonus": true, "forks": []},	# 10
	{"pos": Vector2(627.5, 688.0), "bonus": false, "forks": []},	# 11
	{"pos": Vector2(425.4, 663.4), "bonus": false, "forks": []},	# 12
	{"pos": Vector2(255.8, 626.2), "bonus": false, "forks": []},	# 13
]

const SHAPES := [
	{"label": "0", "type": "rectangle", "cx": 109.8, "cy": 546.8, "rx": 53.9, "ry": 27.7},
	{"label": "1", "type": "ellipse", "cx": 145.4, "cy": 396.2, "rx": 34.1, "ry": 38.8},
	{"label": "2", "type": "ellipse", "cx": 222.3, "cy": 200.5, "rx": 34.1, "ry": 38.8},
	{"label": "3", "type": "ellipse", "cx": 415.7, "cy": 80.0, "rx": 34.1, "ry": 38.8},
	{"label": "4", "type": "ellipse", "cx": 599.6, "cy": 80.0, "rx": 34.1, "ry": 38.8},
	{"label": "5", "type": "ellipse", "cx": 735.9, "cy": 149.7, "rx": 34.1, "ry": 38.8},
	{"label": "6", "type": "ellipse", "cx": 594.0, "cy": 270.2, "rx": 34.1, "ry": 38.8},
	{"label": "7", "type": "ellipse", "cx": 636.8, "cy": 401.0, "rx": 34.1, "ry": 38.8},
	{"label": "8", "type": "ellipse", "cx": 797.7, "cy": 407.3, "rx": 34.1, "ry": 38.8},
	{"label": "9", "type": "ellipse", "cx": 914.2, "cy": 557.1, "rx": 34.1, "ry": 38.8},
	{"label": "10", "type": "ellipse", "cx": 807.2, "cy": 665.7, "rx": 40.4, "ry": 38.8},
	{"label": "11", "type": "ellipse", "cx": 627.5, "cy": 688.0, "rx": 40.4, "ry": 38.8},
	{"label": "12", "type": "ellipse", "cx": 425.4, "cy": 663.4, "rx": 40.4, "ry": 38.8},
	{"label": "13", "type": "ellipse", "cx": 255.8, "cy": 626.2, "rx": 40.4, "ry": 38.8},
]

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1024, 768), BG_COLOR)
	for sh in SHAPES:
		var color: Color = shape_colors.get(sh.label, SHAPE_COLOR)
		if sh.type == "ellipse":
			_draw_ellipse(Vector2(sh.cx, sh.cy), sh.rx, sh.ry, color)
		elif sh.type == "rectangle":
			draw_rect(Rect2(sh.cx - sh.rx, sh.cy - sh.ry, sh.rx * 2, sh.ry * 2), color)
	for sh in SHAPES:
		draw_string(
			ThemeDB.fallback_font,
			Vector2(sh.cx + sh.rx + 4, sh.cy - sh.ry + LABEL_SIZE),
			sh.label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, LABEL_COLOR
		)

func _draw_ellipse(center: Vector2, rx: float, ry: float,
			color: Color = SHAPE_COLOR, steps: int = 48) -> void:
	var pts: PackedVector2Array
	for i in range(steps):
		var a := TAU * i / steps
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)

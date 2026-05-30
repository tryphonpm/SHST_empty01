## Board 03 — généré depuis fond_03.md par generate_scene.py.
## NE PAS ÉDITER MANUELLEMENT.
extends Node2D

const BOARD_TYPE   := "classic"

const BG_COLOR    := Color("#1a3a5c")
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
	{"pos": Vector2(80.0, 507.0), "bonus": false, "forks": []},	# 0
	{"pos": Vector2(113.5, 365.3), "bonus": false, "forks": []},	# 1
	{"pos": Vector2(158.3, 264.7), "bonus": false, "forks": []},	# 2
	{"pos": Vector2(249.2, 193.1), "bonus": false, "forks": []},	# 3
	{"pos": Vector2(367.8, 180.4), "bonus": false, "forks": []},	# 4
	{"pos": Vector2(443.8, 310.1), "bonus": false, "forks": [6, 11]},	# 5
	{"pos": Vector2(613.0, 181.2), "bonus": false, "forks": []},	# 6
	{"pos": Vector2(765.1, 168.5), "bonus": false, "forks": []},	# 7
	{"pos": Vector2(944.0, 340.0), "bonus": false, "forks": []},	# 8
	{"pos": Vector2(924.6, 561.4), "bonus": false, "forks": []},	# 9
	{"pos": Vector2(694.3, 591.2), "bonus": false, "forks": []},	# 10
	{"pos": Vector2(495.4, 470.5), "bonus": false, "forks": []},	# 11
	{"pos": Vector2(383.6, 599.5), "bonus": false, "forks": []},	# 12
	{"pos": Vector2(212.9, 593.5), "bonus": false, "forks": []},	# 13
]

const SHAPES := [
	{"label": "0", "type": "rectangle", "cx": 80.0, "cy": 507.0, "rx": 50.7, "ry": 26.1},
	{"label": "1", "type": "ellipse", "cx": 113.5, "cy": 365.3, "rx": 32.1, "ry": 36.5},
	{"label": "2", "type": "ellipse", "cx": 158.3, "cy": 264.7, "rx": 32.1, "ry": 36.5},
	{"label": "3", "type": "ellipse", "cx": 249.2, "cy": 193.1, "rx": 32.1, "ry": 36.5},
	{"label": "4", "type": "ellipse", "cx": 367.8, "cy": 180.4, "rx": 32.1, "ry": 36.5},
	{"label": "5", "type": "ellipse", "cx": 443.8, "cy": 310.1, "rx": 32.1, "ry": 36.5},
	{"label": "6", "type": "ellipse", "cx": 613.0, "cy": 181.2, "rx": 32.1, "ry": 36.5},
	{"label": "7", "type": "ellipse", "cx": 765.1, "cy": 168.5, "rx": 32.1, "ry": 36.5},
	{"label": "8", "type": "ellipse", "cx": 944.0, "cy": 340.0, "rx": 32.1, "ry": 36.5},
	{"label": "9", "type": "ellipse", "cx": 924.6, "cy": 561.4, "rx": 32.1, "ry": 36.5},
	{"label": "10", "type": "ellipse", "cx": 694.3, "cy": 591.2, "rx": 38.0, "ry": 36.5},
	{"label": "11", "type": "ellipse", "cx": 495.4, "cy": 470.5, "rx": 38.0, "ry": 36.5},
	{"label": "12", "type": "ellipse", "cx": 383.6, "cy": 599.5, "rx": 38.0, "ry": 36.5},
	{"label": "13", "type": "ellipse", "cx": 212.9, "cy": 593.5, "rx": 38.0, "ry": 36.5},
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

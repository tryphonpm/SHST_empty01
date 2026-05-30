extends Control

## Liste des boards disponibles — à synchroniser avec BOARD_CONFIGS dans generate_scene.py.
const BOARDS := [
	{"name": "Board Classique", "scene": "res://game_02.tscn", "color": Color("#ff1450")},
	{"name": "Board Nouveau",   "scene": "res://game_03.tscn", "color": Color("#1a3a5c")},
]

@onready var board_container: VBoxContainer = $Center/Panel/VBox/BoardContainer

func _ready() -> void:
	for i in range(BOARDS.size()):
		var b: Dictionary = BOARDS[i]
		var btn := Button.new()
		btn.text = b["name"]
		btn.custom_minimum_size = Vector2(360, 70)
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		# Fond coloré par board
		var style := StyleBoxFlat.new()
		style.bg_color = b["color"]
		style.corner_radius_top_left     = 10
		style.corner_radius_top_right    = 10
		style.corner_radius_bottom_left  = 10
		style.corner_radius_bottom_right = 10
		btn.add_theme_stylebox_override("normal", style)
		var style_hover := style.duplicate() as StyleBoxFlat
		style_hover.bg_color = b["color"].lightened(0.15)
		btn.add_theme_stylebox_override("hover", style_hover)
		var scene_path: String = b["scene"]
		btn.pressed.connect(func(): _launch(scene_path))
		board_container.add_child(btn)

func _launch(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

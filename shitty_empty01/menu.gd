extends Control

## Joueurs disponibles — doit rester synchronisé avec tmp/players.json.
## Seules les données d'affichage (id, name, color) sont nécessaires ici.
const PLAYERS := [
	{"id": "1", "name": "Danielle", "color": Color("#cc2222")},
	{"id": "2", "name": "Pacha",    "color": Color("#2255cc")},
]

## Liste des boards disponibles — à synchroniser avec BOARD_CONFIGS dans generate_scene.py.
const BOARDS := [
	{"name": "Board Classique",  "scene": "res://game_02.tscn", "color": Color("#ff1450")},
	{"name": "Board Nouveau",    "scene": "res://game_03.tscn", "color": Color("#1a3a5c")},
	{"name": "Quartier Citadin", "scene": "res://game_04.tscn", "color": Color("#1c2b0e")},
]

## Clé Engine.meta utilisée pour transmettre le joueur sélectionné aux scènes de jeu.
const PLAYER_META_KEY: String = "current_player_id"

var selected_player_id: String = PLAYERS[0]["id"]
## Références aux boutons joueur pour pouvoir les re-styliser au changement de sélection.
var player_buttons: Array[Button] = []

@onready var player_container: HBoxContainer = $Center/Panel/VBox/PlayerContainer
@onready var board_container:  VBoxContainer = $Center/Panel/VBox/BoardContainer

func _ready() -> void:
	# Restaurer la sélection précédente si elle existe
	if Engine.has_meta(PLAYER_META_KEY):
		selected_player_id = Engine.get_meta(PLAYER_META_KEY) as String

	_build_player_buttons()
	_build_board_buttons()

# ── Construction UI ───────────────────────────────────────────────────────────

func _build_player_buttons() -> void:
	for p: Dictionary in PLAYERS:
		var pid:   String = p["id"]
		var pname: String = p["name"]
		var pcol:  Color  = p["color"]

		var btn := Button.new()
		btn.text = pname
		btn.custom_minimum_size = Vector2(140, 60)
		btn.add_theme_font_size_override("font_size", 20)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
		btn.toggle_mode = true
		btn.button_pressed = (pid == selected_player_id)

		_apply_player_style(btn, pcol, btn.button_pressed)
		var btn_ref := btn   # capture locale pour la lambda
		btn.toggled.connect(func(pressed: bool) -> void:
			_on_player_toggled(btn_ref, pid, pcol, pressed)
		)
		player_container.add_child(btn)
		player_buttons.append(btn)

func _build_board_buttons() -> void:
	for b: Dictionary in BOARDS:
		var btn := Button.new()
		btn.text = b["name"]
		btn.custom_minimum_size = Vector2(360, 70)
		btn.add_theme_font_size_override("font_size", 26)
		btn.add_theme_color_override("font_color", Color(1, 1, 1))
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
		btn.pressed.connect(func() -> void: _launch(scene_path))
		board_container.add_child(btn)

# ── Logique de sélection joueur ───────────────────────────────────────────────

func _on_player_toggled(btn: Button, pid: String, _pcol: Color, pressed: bool) -> void:
	if not pressed:
		# Empêcher la désélection : un joueur doit toujours être sélectionné.
		btn.set_pressed_no_signal(true)
		return
	selected_player_id = pid
	Engine.set_meta(PLAYER_META_KEY, pid)
	# Dé-sélectionner les autres boutons sans déclencher leur signal toggled.
	for i in range(player_buttons.size()):
		var other: Button = player_buttons[i]
		var other_col: Color = PLAYERS[i]["color"]
		var is_selected: bool = (PLAYERS[i]["id"] == pid)
		other.set_pressed_no_signal(is_selected)
		_apply_player_style(other, other_col, is_selected)

func _apply_player_style(btn: Button, base_color: Color, selected: bool) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = base_color.lightened(0.25) if selected else base_color.darkened(0.35)
	style.border_width_top    = 3 if selected else 0
	style.border_width_bottom = 3 if selected else 0
	style.border_width_left   = 3 if selected else 0
	style.border_width_right  = 3 if selected else 0
	style.border_color = Color(1, 1, 1, 0.9)
	style.corner_radius_top_left     = 10
	style.corner_radius_top_right    = 10
	style.corner_radius_bottom_left  = 10
	style.corner_radius_bottom_right = 10
	btn.add_theme_stylebox_override("normal",   style)
	btn.add_theme_stylebox_override("pressed",  style)
	btn.add_theme_stylebox_override("hover",    style)

# ── Lancement ─────────────────────────────────────────────────────────────────

func _launch(scene_path: String) -> void:
	Engine.set_meta(PLAYER_META_KEY, selected_player_id)
	get_tree().change_scene_to_file(scene_path)

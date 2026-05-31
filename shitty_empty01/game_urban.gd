## Logique de jeu pour les boards de type "urban".
##
## Le parcours est déterminé dynamiquement depuis BOARD_SETUP :
##   streets[current_street][current_sidewalk + "_sidewalk"]
## La direction ("up" / "down") détermine le sens de déplacement (+index / -index).
## Les carrefours (type "fork") permettent de changer de rue/trottoir via une popup.
extends Node2D

const BONUS_DISPLAY_DURATION: float = 2.0
const MENU_SCENE: String            = "res://menu.tscn"
const DEFAULT_PLAYER_ID: String = "1"
const PLAYER_META_KEY: String   = "current_player_id"

signal fork_chosen(label: String)

## Cache plat label→données construit depuis board.BOARD_SETUP à l'initialisation.
var _label_cache: Dictionary = {}

## Label de l'emplacement courant (ex. "B::1", "&::2").
var current_label: String   = ""
## Identifiant du joueur actif (clé dans players).
var current_player_id: String = DEFAULT_PLAYER_ID
## Copie mutable de board.PLAYERS, mise à jour après chaque déplacement.
var players: Dictionary     = {}

var is_moving: bool = false
var game_over: bool = false

@onready var board: Node2D                     = $Board
@onready var player: Node2D                    = $Player
@onready var info_label: Label                 = $UI/InfoLabel
@onready var dice_label: Label                 = $UI/DiceLabel
@onready var roll_button: Button               = $UI/RollButton
@onready var back_button: Button               = $UI/BackButton
@onready var bonus_popup: Panel                = $UI/BonusPopup
@onready var fork_popup: Panel                 = $UI/ForkPopup
@onready var fork_btn_container: VBoxContainer = $UI/ForkPopup/VBox/ButtonContainer

var position_label: Label

func _ready() -> void:
	randomize()
	players = (board.get("PLAYERS") as Dictionary).duplicate(true)
	_build_label_cache()
	current_player_id = Engine.get_meta(PLAYER_META_KEY, DEFAULT_PLAYER_ID) as String
	if not players.has(current_player_id):
		current_player_id = DEFAULT_PLAYER_ID
	_apply_player_color()
	_create_position_label()
	var pdata: Dictionary = players[current_player_id]
	current_label = pdata.get("home", "") as String
	player.position = _data(current_label).get("pos", Vector2.ZERO)
	_update_player_position(current_label)
	roll_button.pressed.connect(_on_roll_pressed)
	back_button.pressed.connect(_on_back_pressed)
	bonus_popup.visible = false
	fork_popup.visible  = false
	roll_button.disabled = false
	_sync_player_node()
	_update_ui()

func _apply_player_color() -> void:
	var color_str: String = players.get(current_player_id, {}).get("color", "white") as String
	var col := Color(color_str)
	var triangle: Polygon2D = player.get_node_or_null("Triangle") as Polygon2D
	if triangle:
		triangle.color = col

func _create_position_label() -> void:
	position_label = Label.new()
	position_label.name = "PositionLabel"
	position_label.anchor_left   = 1.0
	position_label.anchor_top    = 1.0
	position_label.anchor_right  = 1.0
	position_label.anchor_bottom = 1.0
	position_label.offset_left   = -320.0
	position_label.offset_top    = -140.0
	position_label.offset_right  = -12.0
	position_label.offset_bottom = -12.0
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	position_label.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	position_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	position_label.add_theme_font_size_override("font_size", 14)
	$UI.add_child(position_label)

# ── Accesseurs board ──────────────────────────────────────────────────────────

## Retourne les clés ordonnées d'un sidewalk (= séquence de labels à parcourir).
func _get_sidewalk_keys(street: String, sidewalk: String) -> Array:
	var setup: Dictionary = board.get("BOARD_SETUP") as Dictionary
	var streets: Dictionary = setup.get("streets", {}) as Dictionary
	if not streets.has(street):
		return []
	var street_data: Dictionary = streets[street] as Dictionary
	var sw_key: String = sidewalk + "_sidewalk"
	if not street_data.has(sw_key):
		return []
	return (street_data[sw_key] as Dictionary).keys()

## Cherche dans BOARD_SETUP la rue et le trottoir contenant un label donné.
## Retourne {"street": str, "sidewalk": str} ou {} si introuvable.
## Priorité au préfixe du label (ex. "C::1" → cherche d'abord rue "C").
func _find_label_sidewalk(label: String) -> Dictionary:
	var setup: Dictionary = board.get("BOARD_SETUP") as Dictionary
	var streets: Dictionary = setup.get("streets", {}) as Dictionary
	var parts: PackedStringArray = label.split("::")
	var prefix: String = parts[0] if parts.size() > 0 else ""
	if streets.has(prefix):
		var sd: Dictionary = streets[prefix] as Dictionary
		for sw: String in ["even", "odd"]:
			var sw_key: String = sw + "_sidewalk"
			if sd.has(sw_key) and (sd[sw_key] as Dictionary).has(label):
				return {"street": prefix, "sidewalk": sw}
	for sk: String in streets:
		if sk == prefix:
			continue
		var sd: Dictionary = streets[sk] as Dictionary
		for sw: String in ["even", "odd"]:
			var sw_key: String = sw + "_sidewalk"
			if sd.has(sw_key) and (sd[sw_key] as Dictionary).has(label):
				return {"street": sk, "sidewalk": sw}
	return {}

## Construit _label_cache depuis board.BOARD_SETUP["streets"].
## Chaque label est indexé avec : type, pos, directions, street, num, bonus.
func _build_label_cache() -> void:
	var setup: Dictionary = board.get("BOARD_SETUP") as Dictionary
	var streets: Dictionary = setup.get("streets", {}) as Dictionary
	for street_key: String in streets:
		var street_data: Dictionary = streets[street_key] as Dictionary
		for sw_key: String in ["even_sidewalk", "odd_sidewalk"]:
			if not street_data.has(sw_key):
				continue
			var sidewalk: Dictionary = street_data[sw_key] as Dictionary
			for label: String in sidewalk:
				if _label_cache.has(label):
					continue
				var raw: Dictionary = sidewalk[label].duplicate()
				var lparts: PackedStringArray = label.split("::")
				raw["street"] = lparts[0] if lparts.size() > 0 else ""
				var has_num: bool = lparts.size() > 1 and lparts[1].is_valid_int()
				raw["num"]    = int(lparts[1]) if has_num else 0
				raw["bonus"]  = false
				if not raw.has("directions"):
					raw["directions"] = []
				_label_cache[label] = raw

func _data(label: String) -> Dictionary:
	return _label_cache.get(label, {})

# ── Helpers position joueur ───────────────────────────────────────────────────

## Retourne le current_position du joueur actif.
func _player_pos() -> Dictionary:
	return players[current_player_id]["current_position"]

# ── Entrées ──────────────────────────────────────────────────────────────────

func _on_roll_pressed() -> void:
	if is_moving or game_over:
		return
	var roll: int = randi_range(1, 3)
	dice_label.text = "Dé : %d" % roll
	_advance(roll)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

# ── Déplacement ───────────────────────────────────────────────────────────────

func _advance(steps: int) -> void:
	is_moving = true
	roll_button.disabled = true

	var pos: Dictionary  = _player_pos()
	var street: String   = pos["street"]
	var sidewalk: String = pos["sidewalk"]
	var direction: String = pos["direction"]

	var parcours: Array  = _get_sidewalk_keys(street, sidewalk)
	var current_idx: int = parcours.find(current_label)
	if current_idx < 0:
		is_moving = false
		roll_button.disabled = false
		return

	var remaining: int = steps

	# ── Carrefour au DÉPART ───────────────────────────────────────────────
	if _data(current_label).get("type", "") == "fork":
		var dirs: Array = _data(current_label).get("directions", [])
		if dirs.size() > 0:
			var chosen: String = await _show_fork_popup(dirs)
			remaining = maxi(remaining - 1, 0)
			_apply_fork_choice(chosen)
			await _move_player_to(_data(chosen).get("pos", Vector2.ZERO))
			current_label = chosen
			_update_player_position(current_label)
			_update_ui()
			if remaining <= 0:
				if _data(current_label).get("bonus", false):
					await _show_bonus_popup()
				is_moving = false
				roll_button.disabled = false
				return
			pos = _player_pos()
			street = pos["street"]
			sidewalk = pos["sidewalk"]
			direction = pos["direction"]
			parcours = _get_sidewalk_keys(street, sidewalk)
			current_idx = parcours.find(current_label)
			if current_idx < 0:
				is_moving = false
				roll_button.disabled = false
				return

	# ── Boucle de déplacement ─────────────────────────────────────────────
	while remaining > 0:
		remaining -= 1
		if direction == "down":
			current_idx -= 1
		else:
			current_idx += 1

		if current_idx < 0 or current_idx >= parcours.size():
			_end_game()
			return

		current_label = parcours[current_idx]
		await _move_player_to(_data(current_label).get("pos", Vector2.ZERO))
		_update_player_position(current_label)
		_update_ui()

		# Carrefour EN TRANSIT (pas sur la case d'arrivée finale)
		if remaining > 0 and _data(current_label).get("type", "") == "fork":
			var dirs: Array = _data(current_label).get("directions", [])
			if dirs.size() > 0:
				var chosen: String = await _show_fork_popup(dirs)
				remaining = maxi(remaining - 1, 0)
				_apply_fork_choice(chosen)
				await _move_player_to(_data(chosen).get("pos", Vector2.ZERO))
				current_label = chosen
				_update_player_position(current_label)
				_update_ui()
				pos = _player_pos()
				street = pos["street"]
				sidewalk = pos["sidewalk"]
				direction = pos["direction"]
				parcours = _get_sidewalk_keys(street, sidewalk)
				current_idx = parcours.find(current_label)
				if current_idx < 0:
					is_moving = false
					roll_button.disabled = false
					return

	# ── Bonus sur la case d'arrivée finale ───────────────────────────────
	if _data(current_label).get("bonus", false):
		await _show_bonus_popup()

	is_moving = false
	roll_button.disabled = false

## Applique le résultat d'un choix de carrefour : met à jour street/sidewalk du joueur.
func _apply_fork_choice(chosen_label: String) -> void:
	var loc: Dictionary = _find_label_sidewalk(chosen_label)
	if loc.is_empty():
		return
	var pos: Dictionary = _player_pos()
	pos["street"]   = loc["street"]
	pos["sidewalk"] = loc["sidewalk"]

## Déplace le joueur en douceur (Tween) vers une position en coordonnées Godot.
func _move_player_to(target: Vector2) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(player, "position", target, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

# ── Popup de choix de direction (carrefour) ───────────────────────────────────

func _show_fork_popup(fork_opts: Array) -> String:
	for child in fork_btn_container.get_children():
		child.queue_free()
	for opt in fork_opts:
		var lbl: String = opt as String
		var btn := Button.new()
		btn.text = lbl
		btn.pressed.connect(func() -> void: fork_chosen.emit(lbl))
		fork_btn_container.add_child(btn)
	fork_popup.visible = true
	var chosen: String = await fork_chosen
	fork_popup.visible = false
	return chosen

# ── Popups ────────────────────────────────────────────────────────────────────

func _show_bonus_popup() -> void:
	bonus_popup.visible = true
	await get_tree().create_timer(BONUS_DISPLAY_DURATION).timeout
	bonus_popup.visible = false

# ── État joueur ───────────────────────────────────────────────────────────────

## Met à jour current_position après chaque pas.
## street et sidewalk sont gérés par _apply_fork_choice, pas ici.
func _update_player_position(label: String) -> void:
	if not players.has(current_player_id):
		return
	var d: Dictionary   = _data(label)
	var pos: Dictionary = _player_pos()
	pos["num"]              = d.get("num", 0)
	var t: String = d.get("type", "")
	pos["address_fork"]     = label if t == "fork"    else ""
	pos["address_passage"]  = label if t == "passage" else ""
	_sync_player_node()

func _sync_player_node() -> void:
	var pscript: Script = player.get_script() as Script
	if pscript == null:
		return
	player.call("sync_from_dict", current_player_id, players[current_player_id])

# ── État ──────────────────────────────────────────────────────────────────────

func _end_game() -> void:
	game_over        = true
	is_moving        = false
	roll_button.disabled = true
	info_label.text  = "Bravo ! Tu as atteint la dernière adresse.\nPartie terminée."

func _update_ui() -> void:
	if game_over:
		return
	var pos: Dictionary = _player_pos()
	var sw_keys: Array  = _get_sidewalk_keys(pos["street"], pos["sidewalk"])
	var idx: int        = sw_keys.find(current_label)
	info_label.text = (
		"Adresse : %s  (%d/%d — %s %s)\nLance le dé (1 à 3) pour avancer."
		% [current_label, idx + 1, sw_keys.size(), pos["street"], pos["sidewalk"]]
	)
	_update_position_label()

func _update_position_label() -> void:
	if position_label == null or not players.has(current_player_id):
		return
	var pos: Dictionary = _player_pos()
	var pname: String   = players[current_player_id].get("name", current_player_id)
	position_label.text = (
		"%s\nstreet : %s    sidewalk : %s\nnum : %s    direction : %s\nfork : %s\npassage : %s"
		% [
			pname,
			str(pos.get("street", "")),
			str(pos.get("sidewalk", "")),
			str(pos.get("num", "")),
			str(pos.get("direction", "")),
			str(pos.get("address_fork", "")),
			str(pos.get("address_passage", "")),
		]
	)

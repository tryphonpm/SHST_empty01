## Logique de jeu pour les boards de type "urban".
##
## Le parcours est déterminé dynamiquement depuis BOARD_SETUP :
##   streets[current_street][current_sidewalk + "_sidewalk"]
## La direction ("up" / "down") détermine le sens (+index / -index).
## Les carrefours (type "fork") proposent des flèches SVG via une popup.
## Chaque flèche porte un objet parcours {visuel, street, sidewalk, direction}
## qui redéfinit la liste de déplacement de référence pour la suite du tour.
extends Node2D

const BONUS_DISPLAY_DURATION: float = 2.0
const MENU_SCENE: String            = "res://menu.tscn"
const ARROW_DIR: String             = "res://visuels/arrows/"
const DEFAULT_PLAYER_ID: String = "1"
const PLAYER_META_KEY: String   = "current_player_id"

signal fork_chosen(choice: String)

var _label_cache: Dictionary = {}

var current_label: String   = ""
var current_player_id: String = DEFAULT_PLAYER_ID
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
	current_player_id = (
		Engine.get_meta(PLAYER_META_KEY, DEFAULT_PLAYER_ID) as String
	)
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
	var color_str: String = (
		players.get(current_player_id, {}).get("color", "white") as String
	)
	var col := Color(color_str)
	var tri: Polygon2D = player.get_node_or_null("Triangle") as Polygon2D
	if tri:
		tri.color = col

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
	position_label.add_theme_color_override(
		"font_color", Color(1, 1, 1, 0.85)
	)
	position_label.add_theme_font_size_override("font_size", 14)
	$UI.add_child(position_label)

# ── Accesseurs board ──────────────────────────────────────────────────

## Clés ordonnées d'un sidewalk (= séquence de labels à parcourir).
func _get_sidewalk_keys(street: String, sidewalk: String) -> Array:
	var setup: Dictionary = board.get("BOARD_SETUP") as Dictionary
	var streets: Dictionary = setup.get("streets", {}) as Dictionary
	if not streets.has(street):
		return []
	var sd: Dictionary = streets[street] as Dictionary
	var sw_key: String = sidewalk + "_sidewalk"
	if not sd.has(sw_key):
		return []
	return (sd[sw_key] as Dictionary).keys()

## Lit le tableau parcours d'un fork depuis BOARD_SETUP (contexte-dépendant).
## Un même fork a des parcours différents selon le sidewalk d'approche.
func _get_fork_parcours(
	label: String, street: String, sidewalk: String
) -> Array:
	var setup: Dictionary = board.get("BOARD_SETUP") as Dictionary
	var streets: Dictionary = setup.get("streets", {}) as Dictionary
	if not streets.has(street):
		return []
	var sd: Dictionary = streets[street] as Dictionary
	var sw_key: String = sidewalk + "_sidewalk"
	if not sd.has(sw_key):
		return []
	var sw: Dictionary = sd[sw_key] as Dictionary
	if not sw.has(label):
		return []
	return (sw[label] as Dictionary).get("parcours", [])

## Trouve l'index du label le plus proche (distance physique) dans sw_keys.
## Utilisé quand le fork label n'existe pas dans le sidewalk de destination.
func _find_nearest_idx(ref_label: String, sw_keys: Array) -> int:
	var ref_pos: Vector2 = _data(ref_label).get("pos", Vector2.ZERO)
	var best: int   = 0
	var best_d: float = INF
	for i in range(sw_keys.size()):
		var p: Vector2 = _data(sw_keys[i]).get("pos", Vector2.ZERO)
		var d: float   = ref_pos.distance_to(p)
		if d < best_d:
			best_d = d
			best   = i
	return best

## Cache plat label→données (type, pos, street, num, bonus).
## Les parcours ne sont PAS stockés ici (contexte-dépendants).
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
				raw.erase("parcours")
				var lp: PackedStringArray = label.split("::")
				raw["street"] = lp[0] if lp.size() > 0 else ""
				var has_n: bool = (
					lp.size() > 1 and lp[1].is_valid_int()
				)
				raw["num"]   = int(lp[1]) if has_n else 0
				raw["bonus"] = false
				_label_cache[label] = raw

func _data(label: String) -> Dictionary:
	return _label_cache.get(label, {})

## Retourne le current_position du joueur actif.
func _player_pos() -> Dictionary:
	return players[current_player_id]["current_position"]

# ── Entrées ───────────────────────────────────────────────────────────

func _on_roll_pressed() -> void:
	if is_moving or game_over:
		return
	var roll: int = randi_range(1, 3)
	dice_label.text = "Dé : %d" % roll
	_advance(roll)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

# ── Déplacement ───────────────────────────────────────────────────────

func _advance(steps: int) -> void:
	is_moving = true
	roll_button.disabled = true

	var pos: Dictionary   = _player_pos()
	var street: String    = pos["street"]
	var sidewalk: String  = pos["sidewalk"]
	var direction: String = pos["direction"]

	var sw_keys: Array  = _get_sidewalk_keys(street, sidewalk)
	var cur_idx: int    = sw_keys.find(current_label)
	if cur_idx < 0:
		is_moving = false
		roll_button.disabled = false
		return

	var remaining: int = steps

	# ── Carrefour au DÉPART ───────────────────────────────────────────
	if _data(current_label).get("type", "") == "fork":
		var opts: Array = _get_fork_parcours(
			current_label, street, sidewalk
		)
		if opts.size() > 0:
			var chosen: Dictionary = await _show_fork_popup(opts)
			remaining = maxi(remaining - 1, 0)
			_apply_fork_choice(chosen)
			# Recalcul après changement de sidewalk
			pos       = _player_pos()
			street    = pos["street"]
			sidewalk  = pos["sidewalk"]
			direction = pos["direction"]
			sw_keys   = _get_sidewalk_keys(street, sidewalk)
			cur_idx   = sw_keys.find(current_label)
			if cur_idx < 0:
				cur_idx = _find_nearest_idx(current_label, sw_keys)
				current_label = sw_keys[cur_idx]
				await _move_player_to(
					_data(current_label).get("pos", Vector2.ZERO)
				)
				_update_player_position(current_label)
				_update_ui()
			if remaining <= 0:
				_finish_move()
				return

	# ── Boucle de déplacement ─────────────────────────────────────────
	while remaining > 0:
		remaining -= 1
		if direction == "down":
			cur_idx -= 1
		else:
			cur_idx += 1

		if cur_idx < 0 or cur_idx >= sw_keys.size():
			_end_game()
			return

		current_label = sw_keys[cur_idx]
		await _move_player_to(
			_data(current_label).get("pos", Vector2.ZERO)
		)
		_update_player_position(current_label)
		_update_ui()

		# Carrefour EN TRANSIT (pas sur la case d'arrivée finale)
		if remaining > 0:
			if _data(current_label).get("type", "") == "fork":
				var opts: Array = _get_fork_parcours(
					current_label, street, sidewalk
				)
				if opts.size() > 0:
					var chosen: Dictionary = (
						await _show_fork_popup(opts)
					)
					remaining = maxi(remaining - 1, 0)
					_apply_fork_choice(chosen)
					pos       = _player_pos()
					street    = pos["street"]
					sidewalk  = pos["sidewalk"]
					direction = pos["direction"]
					sw_keys   = _get_sidewalk_keys(street, sidewalk)
					cur_idx   = sw_keys.find(current_label)
					if cur_idx < 0:
						cur_idx = _find_nearest_idx(
							current_label, sw_keys
						)
						current_label = sw_keys[cur_idx]
						await _move_player_to(
							_data(current_label).get(
								"pos", Vector2.ZERO
							)
						)
						_update_player_position(current_label)
						_update_ui()

	_finish_move()

## Termine le déplacement : bonus éventuel + réactivation du bouton.
func _finish_move() -> void:
	if _data(current_label).get("bonus", false):
		await _show_bonus_popup()
	is_moving = false
	roll_button.disabled = false

## Applique un objet parcours sur le joueur actif.
func _apply_fork_choice(parcours_obj: Dictionary) -> void:
	var pos: Dictionary = _player_pos()
	pos["street"]    = parcours_obj.get("street",    pos["street"])
	pos["sidewalk"]  = parcours_obj.get("sidewalk",  pos["sidewalk"])
	pos["direction"] = parcours_obj.get("direction", pos["direction"])
	_sync_player_node()

func _move_player_to(target: Vector2) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(player, "position", target, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

# ── Popup flèches SVG (carrefour) ────────────────────────────────────

## Affiche une popup avec les flèches SVG du parcours.
## Retourne le Dictionary {visuel, street, sidewalk, direction} choisi.
func _show_fork_popup(parcours_opts: Array) -> Dictionary:
	for child in fork_btn_container.get_children():
		child.queue_free()

	for i in range(parcours_opts.size()):
		var opt: Dictionary = parcours_opts[i] as Dictionary
		var visuel: String  = opt.get("visuel", "arrow_front.svg")
		if not visuel.ends_with(".svg"):
			visuel += ".svg"
		var tex_path: String = ARROW_DIR + visuel

		var btn := TextureButton.new()
		var tex: Texture2D = load(tex_path) as Texture2D
		if tex:
			btn.texture_normal = tex
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(64, 64)
		var idx: int = i
		btn.pressed.connect(
			func() -> void: fork_chosen.emit(str(idx))
		)
		fork_btn_container.add_child(btn)

	fork_popup.visible = true
	var chosen_str: String = await fork_chosen
	fork_popup.visible = false
	return parcours_opts[int(chosen_str)] as Dictionary

# ── Popups ────────────────────────────────────────────────────────────

func _show_bonus_popup() -> void:
	bonus_popup.visible = true
	await get_tree().create_timer(BONUS_DISPLAY_DURATION).timeout
	bonus_popup.visible = false

# ── État joueur ───────────────────────────────────────────────────────

## Met à jour num, address_fork, address_passage après chaque pas.
## street / sidewalk / direction sont gérés par _apply_fork_choice.
func _update_player_position(label: String) -> void:
	if not players.has(current_player_id):
		return
	var d: Dictionary   = _data(label)
	var pos: Dictionary = _player_pos()
	pos["num"] = d.get("num", 0)
	var t: String = d.get("type", "")
	pos["address_fork"]    = label if t == "fork"    else ""
	pos["address_passage"] = label if t == "passage" else ""
	_sync_player_node()

func _sync_player_node() -> void:
	var pscript: Script = player.get_script() as Script
	if pscript == null:
		return
	player.call(
		"sync_from_dict",
		current_player_id,
		players[current_player_id],
	)

# ── État ──────────────────────────────────────────────────────────────

func _end_game() -> void:
	game_over            = true
	is_moving            = false
	roll_button.disabled = true
	info_label.text = (
		"Bravo ! Fin du trottoir atteinte.\nPartie terminée."
	)

func _update_ui() -> void:
	if game_over:
		return
	var pos: Dictionary = _player_pos()
	var sw_keys: Array  = _get_sidewalk_keys(
		pos["street"], pos["sidewalk"]
	)
	var idx: int = sw_keys.find(current_label)
	info_label.text = (
		"Adresse : %s  (%d/%d — %s.%s %s)\nDé (1-3)"
		% [
			current_label, idx + 1, sw_keys.size(),
			pos["street"], pos["sidewalk"], pos["direction"],
		]
	)
	_update_position_label()

func _update_position_label() -> void:
	if position_label == null:
		return
	if not players.has(current_player_id):
		return
	var pos: Dictionary = _player_pos()
	var pname: String = (
		players[current_player_id].get("name", current_player_id)
	)
	position_label.text = (
		"%s\nstreet: %s  sidewalk: %s\nnum: %s  direction: %s"
		+ "\nfork: %s\npassage: %s"
	) % [
		pname,
		str(pos.get("street", "")),
		str(pos.get("sidewalk", "")),
		str(pos.get("num", "")),
		str(pos.get("direction", "")),
		str(pos.get("address_fork", "")),
		str(pos.get("address_passage", "")),
	]

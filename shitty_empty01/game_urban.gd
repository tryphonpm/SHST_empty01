## Logique de jeu pour les boards de type "urban".
##
## Différences fondamentales avec game.gd (classic) :
##   - Les emplacements sont identifiés par des labels string ("B::1", "&::2", "@::3")
##     au lieu d'indices entiers.
##   - board.BOARD_DATA est un Dictionary keyed par label (non plus un Array).
##   - Le parcours est défini explicitement dans board.PARCOURS (liste ordonnée de labels).
##   - La fin de partie survient quand le joueur atteint/dépasse le dernier label du PARCOURS,
##     et non en revenant sur la case 0.
##   - Les carrefours (type "fork") sont détectés via BOARD_DATA[label]["type"] == "fork".
##   - Le choix de direction au carrefour est proposé au joueur via une popup interactive.
extends Node2D

const BONUS_DISPLAY_DURATION: float = 2.0
const MENU_SCENE: String            = "res://menu.tscn"
## Identifiant du joueur actif par défaut. Correspond aux clés de board.PLAYERS.
const DEFAULT_PLAYER_ID: String = "1"
## Clé Engine.meta utilisée par menu.gd pour transmettre le joueur sélectionné.
const PLAYER_META_KEY: String   = "current_player_id"

## Émis par la popup de carrefour quand le joueur clique sur une direction.
signal fork_chosen(label: String)

## Cache plat label→données construit depuis board.BOARD_SETUP à l'initialisation.
## Permet un accès O(1) équivalent à l'ancien BOARD_DATA.
var _label_cache: Dictionary = {}

## Index courant dans board.PARCOURS (0 = départ).
var parcours_idx: int       = 0
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

## Label bas-droite affichant current_position du joueur actif (créé en code).
var position_label: Label

func _ready() -> void:
	randomize()
	players = (board.get("PLAYERS") as Dictionary).duplicate(true)
	_build_label_cache()
	# Lire le joueur choisi dans le menu (fallback : DEFAULT_PLAYER_ID)
	current_player_id = Engine.get_meta(PLAYER_META_KEY, DEFAULT_PLAYER_ID) as String
	if not players.has(current_player_id):
		current_player_id = DEFAULT_PLAYER_ID
	_apply_player_color()
	_create_position_label()
	var parcours: Array = _parcours()
	parcours_idx  = 0
	current_label = parcours[0] if parcours.size() > 0 else ""
	player.position = _data(current_label).get("pos", Vector2.ZERO)
	roll_button.pressed.connect(_on_roll_pressed)
	back_button.pressed.connect(_on_back_pressed)
	bonus_popup.visible = false
	fork_popup.visible  = false
	roll_button.disabled = false
	_sync_player_node()
	_update_ui()

## Applique la couleur du joueur actif au Triangle (Polygon2D enfant de Player).
func _apply_player_color() -> void:
	var color_str: String = players.get(current_player_id, {}).get("color", "white") as String
	var col := Color(color_str)
	var triangle: Polygon2D = player.get_node_or_null("Triangle") as Polygon2D
	if triangle:
		triangle.color = col

## Crée le label bas-droite affichant current_position (non inclus dans la scène générée).
func _create_position_label() -> void:
	position_label = Label.new()
	position_label.name = "PositionLabel"
	# Ancrage bas-droite
	position_label.anchor_left   = 1.0
	position_label.anchor_top    = 1.0
	position_label.anchor_right  = 1.0
	position_label.anchor_bottom = 1.0
	position_label.offset_left   = -320.0
	position_label.offset_top    = -130.0
	position_label.offset_right  = -12.0
	position_label.offset_bottom = -12.0
	position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	position_label.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	position_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	position_label.add_theme_font_size_override("font_size", 14)
	$UI.add_child(position_label)

# ── Accesseurs board ──────────────────────────────────────────────────────────

## Retourne board.PARCOURS en tant qu'Array.
func _parcours() -> Array:
	return board.get("PARCOURS") as Array

## Construit _label_cache depuis board.BOARD_SETUP["streets"].
## Chaque label est indexé avec : type, pos, directions, street, num, bonus.
## Les labels présents dans plusieurs sidewalks ne sont indexés qu'une fois.
func _build_label_cache() -> void:
	var setup: Dictionary = board.get("BOARD_SETUP") as Dictionary
	var streets: Dictionary = setup.get("streets", {}) as Dictionary
	for street_key: String in streets:
		var street_data: Dictionary = streets[street_key] as Dictionary
		for sw_key: String in ["even_sidewalk", "oden_sidewalk", "odd_sidewalk"]:
			if not street_data.has(sw_key):
				continue
			var sidewalk: Dictionary = street_data[sw_key] as Dictionary
			for label: String in sidewalk:
				if _label_cache.has(label):
					continue  # label partagé entre sidewalks : indexé une seule fois
				var raw: Dictionary = sidewalk[label].duplicate()
				var parts: PackedStringArray = label.split("::")
				raw["street"] = parts[0] if parts.size() > 0 else ""
				raw["num"]    = int(parts[1]) if parts.size() > 1 and parts[1].is_valid_int() else 0
				raw["bonus"]  = false
				if not raw.has("directions"):
					raw["directions"] = []
				_label_cache[label] = raw

## Retourne le dict de données pour un label donné, ou {} si inconnu.
func _data(label: String) -> Dictionary:
	return _label_cache.get(label, {})

# ── Setup ─────────────────────────────────────────────────────────────────────

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

	var parcours: Array = _parcours()
	var remaining: int  = steps

	# ── Carrefour au DÉPART ───────────────────────────────────────────────────
	# Si la case de départ de ce tour est un fork, proposer le choix AVANT de bouger.
	# Le déplacement vers la destination choisie consomme 1 pas.
	# • Si la destination choisie est plus loin dans le PARCOURS → avance case par case
	#   (pas de téléport : la boucle ci-dessous prend le relais normalement).
	# • Si la destination est hors-PARCOURS (vraie déviation) → _jump_to_label.
	if _data(current_label).get("type", "") == "fork":
		var fork_opts: Array = _data(current_label).get("directions", [])
		if fork_opts.size() > 0:
			var chosen: String = await _show_fork_popup(fork_opts)
			_update_player_direction(chosen)
			remaining = maxi(remaining - 1, 0)
			var chosen_idx: int = parcours.find(chosen)
			if chosen_idx < 0 or chosen_idx <= parcours_idx:
				await _jump_to_label(chosen, parcours)
				if game_over:
					return
			# else : destination en avant dans le PARCOURS → la boucle avance normalement

	# ── Boucle de déplacement ─────────────────────────────────────────────────
	while remaining > 0:
		remaining -= 1
		parcours_idx += 1

		# Fin du parcours (atteint ou dépassé la dernière adresse)
		if parcours_idx >= parcours.size():
			_end_game()
			return

		current_label = parcours[parcours_idx]
		await _move_player_to(_data(current_label).get("pos", Vector2.ZERO))
		_update_player_position(current_label)
		_update_ui()

		# Carrefour EN TRANSIT : uniquement si des pas restent après ce déplacement.
		# → La case d'arrivée finale ne déclenche JAMAIS le fork.
		# → Même règle que le DÉPART : téléport seulement si la destination est hors-PARCOURS.
		if remaining > 0 and _data(current_label).get("type", "") == "fork":
			var fork_opts: Array = _data(current_label).get("directions", [])
			if fork_opts.size() > 0:
				var chosen: String = await _show_fork_popup(fork_opts)
				_update_player_direction(chosen)
				remaining = maxi(remaining - 1, 0)
				var chosen_idx: int = parcours.find(chosen)
				if chosen_idx < 0 or chosen_idx <= parcours_idx:
					await _jump_to_label(chosen, parcours)
					if game_over:
						return
				# else : destination en avant dans le PARCOURS → la boucle continue normalement

	# ── Bonus sur la case d'arrivée finale ───────────────────────────────────
	if _data(current_label).get("bonus", false):
		await _show_bonus_popup()

	is_moving = false
	roll_button.disabled = false

## Saute directement vers un label (fork ou autre), met à jour parcours_idx.
## Déclenche _end_game si le label est le dernier du PARCOURS ou hors bounds.
func _jump_to_label(label: String, parcours: Array) -> void:
	var idx: int = parcours.find(label)
	if idx >= 0:
		parcours_idx = idx
	current_label = label
	await _move_player_to(_data(label).get("pos", Vector2.ZERO))
	_update_player_position(current_label)
	_update_ui()
	if parcours_idx >= parcours.size() - 1:
		_end_game()

## Déplace le joueur en douceur (Tween) vers une position en coordonnées Godot.
func _move_player_to(target: Vector2) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(player, "position", target, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

# ── Popup de choix de direction (carrefour) ───────────────────────────────────

## Affiche la popup de carrefour et attend que le joueur clique sur une option.
## Chaque bouton correspond à un label de fork_opts.
## Retourne le label choisi via le signal fork_chosen.
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

## Met à jour current_position du joueur actif après chaque déplacement.
## • street / num   : issus de BOARD_DATA[label]
## • address_fork   : label si type=="fork",    sinon ""
## • address_passage: label si type=="passage", sinon ""
## Synchronise aussi le node Player (exports inspecteur).
func _update_player_position(label: String) -> void:
	if not players.has(current_player_id):
		return
	var d: Dictionary   = _data(label)
	var pos: Dictionary = players[current_player_id]["current_position"]
	pos["street"]           = d.get("street", "")
	pos["num"]              = d.get("num", 0)
	var t: String = d.get("type", "")
	pos["address_fork"]     = label if t == "fork"    else ""
	pos["address_passage"]  = label if t == "passage" else ""
	_sync_player_node()

## Met à jour la clé direction du joueur actif lors d'un choix de carrefour.
## chosen_label : label choisi dans la popup fork (ex. "B::13", "C::1").
## Synchronise aussi le node Player (exports inspecteur).
func _update_player_direction(chosen_label: String) -> void:
	if not players.has(current_player_id):
		return
	players[current_player_id]["current_position"]["direction"] = chosen_label
	_sync_player_node()

## Pousse les données de players[current_player_id] dans les @export du node Player.
## Permet de voir les valeurs actualisées dans l'onglet Remote de l'inspecteur.
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
	var parcours: Array = _parcours()
	info_label.text = (
		"Adresse : %s  (%d/%d)\nLance le dé (1 à 3) pour avancer."
		% [current_label, parcours_idx + 1, parcours.size()]
	)
	_update_position_label()

## Rafraîchit le label bas-droite avec current_position du joueur actif.
func _update_position_label() -> void:
	if position_label == null or not players.has(current_player_id):
		return
	var pos: Dictionary = players[current_player_id]["current_position"]
	var pname: String   = players[current_player_id].get("name", current_player_id)
	position_label.text = (
		"%s\nstreet : %s    num : %s\ndirection : %s\nfork : %s\npassage : %s"
		% [
			pname,
			str(pos.get("street", "")),
			str(pos.get("num", "")),
			str(pos.get("direction", "")),
			str(pos.get("address_fork", "")),
			str(pos.get("address_passage", "")),
		]
	)

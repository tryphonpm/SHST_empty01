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

## Émis par la popup de carrefour quand le joueur clique sur une direction.
signal fork_chosen(label: String)

## Index courant dans board.PARCOURS (0 = départ).
var parcours_idx: int     = 0
## Label de l'emplacement courant (ex. "B::1", "&::2").
var current_label: String = ""

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

func _ready() -> void:
	randomize()
	var parcours: Array = _parcours()
	parcours_idx  = 0
	current_label = parcours[0] if parcours.size() > 0 else ""
	player.position = _data(current_label).get("pos", Vector2.ZERO)
	roll_button.pressed.connect(_on_roll_pressed)
	back_button.pressed.connect(_on_back_pressed)
	bonus_popup.visible = false
	fork_popup.visible  = false
	roll_button.disabled = false
	_update_ui()

# ── Accesseurs board ──────────────────────────────────────────────────────────

## Retourne board.PARCOURS en tant qu'Array.
func _parcours() -> Array:
	return board.get("PARCOURS") as Array

## Retourne le dict de données pour un label donné, ou {} si inconnu.
func _data(label: String) -> Dictionary:
	var bd: Dictionary = board.get("BOARD_DATA") as Dictionary
	return bd.get(label, {})

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
		var fork_opts: Array = _data(current_label).get("forks", [])
		if fork_opts.size() > 0:
			var chosen: String = await _show_fork_popup(fork_opts)
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
		_update_ui()

		# Carrefour EN TRANSIT : uniquement si des pas restent après ce déplacement.
		# → La case d'arrivée finale ne déclenche JAMAIS le fork.
		# → Même règle que le DÉPART : téléport seulement si la destination est hors-PARCOURS.
		if remaining > 0 and _data(current_label).get("type", "") == "fork":
			var fork_opts: Array = _data(current_label).get("forks", [])
			if fork_opts.size() > 0:
				var chosen: String = await _show_fork_popup(fork_opts)
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

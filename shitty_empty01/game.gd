## Logique de jeu partagée entre tous les boards.
## Chaque scène game_XX.tscn utilise ce script.
extends Node2D

const BONUS_DISPLAY_DURATION: float = 2.0
const MENU_SCENE: String = "res://menu.tscn"

## Émis quand le joueur clique sur un bouton de direction dans la ForkPopup.
signal fork_chosen(case_idx: int)

## Index de la case courante dans BOARD_DATA (0 = départ/arrivée).
var current_idx: int = 0
## true dès le premier lancer, pour distinguer "au départ" de "retour au départ".
var has_started: bool = false
var is_moving: bool = false
var game_over: bool = false

@onready var board: Node2D                = $Board
@onready var player: Node2D               = $Player
@onready var info_label: Label            = $UI/InfoLabel
@onready var dice_label: Label            = $UI/DiceLabel
@onready var roll_button: Button          = $UI/RollButton
@onready var back_button: Button          = $UI/BackButton
@onready var bonus_popup: Panel           = $UI/BonusPopup
@onready var fork_popup: Panel            = $UI/ForkPopup
@onready var fork_btn_container: VBoxContainer = $UI/ForkPopup/VBox/ButtonContainer

func _ready() -> void:
	randomize()
	player.position = board.BOARD_DATA[0]["pos"]
	roll_button.pressed.connect(_on_roll_pressed)
	back_button.pressed.connect(_on_back_pressed)
	bonus_popup.visible = false
	fork_popup.visible = false
	roll_button.disabled = true
	await _run_setup()
	roll_button.disabled = false
	_update_ui()

# ── Setup ─────────────────────────────────────────────────────────────────────

## Retourne la liste ordonnée des fonctions de setup à exécuter avant chaque partie.
## Pour ajouter une nouvelle étape : décommenter ou ajouter une ligne ici.
func _get_setup_steps() -> Array[Callable]:
	return [
		_setup_colored_positions,
		# _setup_future_feature,
	]

## Exécute toutes les étapes de setup dans l'ordre.
func _run_setup() -> void:
	for step: Callable in _get_setup_steps():
		await step.call()

## Setup #1 — Colorisation aléatoire de N cases au démarrage de la partie.
## Modifie uniquement l'aspect visuel ; ne change pas BOARD_DATA.
## Pour changer le nombre ou la couleur, éditer les constantes ci-dessous.
func _setup_colored_positions() -> void:
	const COUNT: int = 3
	const COLOR: Color = Color(143.0 / 255.0, 11.0 / 255.0, 25.0 / 255.0)  # maroon RGB(143,11,25)

	# Construire la liste des indices candidats (on exclut la case 0 = départ)
	var candidates: Array[int] = []
	for i in range(1, board.BOARD_DATA.size()):
		candidates.append(i)
	candidates.shuffle()

	for i in range(mini(COUNT, candidates.size())):
		board.set_shape_color(str(candidates[i]), COLOR)

# ── Entrées ──────────────────────────────────────────────────────────────────

func _on_roll_pressed() -> void:
	if is_moving or game_over:
		return
	has_started = true
	var roll: int = randi_range(1, 3)
	dice_label.text = "Dé : %d" % roll
	_advance(roll)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)

# ── Déplacement ───────────────────────────────────────────────────────────────

func _advance(steps: int) -> void:
	is_moving = true
	roll_button.disabled = true

	var remaining: int = steps

	# ── Carrefour au DÉPART ───────────────────────────────────────────────────
	# Si la case courante (= case de départ de ce tour) est un carrefour,
	# proposer le choix de direction AVANT de bouger.
	# Le déplacement vers la direction choisie consomme 1 pas.
	var start_forks: Array = board.BOARD_DATA[current_idx].get("forks", [])
	if start_forks.size() > 0:
		await _show_fork_popup(start_forks)   # met à jour current_idx
		remaining = maxi(remaining - 1, 0)
		if current_idx == 0:
			_end_game()
			return

	# ── Boucle de déplacement ─────────────────────────────────────────────────
	while remaining > 0:
		remaining -= 1
		current_idx = (current_idx + 1) % board.BOARD_DATA.size()
		await _move_player_to(current_idx)
		_update_ui()

		if current_idx == 0:
			_end_game()
			return

		# Carrefour EN TRANSIT : uniquement si des pas restent après ce déplacement.
		# → La case d'arrivée finale ne déclenche JAMAIS le fork popup.
		if remaining > 0:
			var forks: Array = board.BOARD_DATA[current_idx].get("forks", [])
			if forks.size() > 0:
				await _show_fork_popup(forks)   # met à jour current_idx
				remaining = maxi(remaining - 1, 0)
				if current_idx == 0:
					_end_game()
					return

	# ── Bonus : uniquement sur la case d'arrivée finale ───────────────────────
	if board.BOARD_DATA[current_idx]["bonus"]:
		await _show_bonus_popup()

	is_moving = false
	roll_button.disabled = false

func _move_player_to(idx: int) -> void:
	var target: Vector2 = board.BOARD_DATA[idx]["pos"]
	var tween: Tween = create_tween()
	tween.tween_property(player, "position", target, 0.25) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished

# ── Popups ────────────────────────────────────────────────────────────────────

func _show_bonus_popup() -> void:
	bonus_popup.visible = true
	await get_tree().create_timer(BONUS_DISPLAY_DURATION).timeout
	bonus_popup.visible = false

func _show_fork_popup(forks: Array) -> void:
	# Vider les boutons du tour précédent
	for child in fork_btn_container.get_children():
		child.queue_free()

	# Créer un bouton par direction possible
	for idx in forks:
		var btn := Button.new()
		btn.text = "-> Case %d" % idx
		btn.custom_minimum_size = Vector2(220, 52)
		btn.add_theme_font_size_override("font_size", 22)
		var captured: int = idx
		btn.pressed.connect(func(): fork_chosen.emit(captured))
		fork_btn_container.add_child(btn)

	fork_popup.visible = true
	var chosen_idx: int = await fork_chosen
	fork_popup.visible = false

	# Déplacer le joueur vers la direction choisie
	await _move_player_to(chosen_idx)
	current_idx = chosen_idx
	_update_ui()

# ── État ──────────────────────────────────────────────────────────────────────

func _end_game() -> void:
	game_over = true
	is_moving = false
	roll_button.disabled = true
	info_label.text = "Bravo ! Tu as rejoint le départ (0).\nPartie terminée."

func _update_ui() -> void:
	if game_over:
		return
	info_label.text = "Case actuelle : %d\nLance le dé (1 à 3) pour avancer." % current_idx

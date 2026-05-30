extends Node2D

## Positions des emplacements numérotés (0 à 10) détectées sur le fond.
## L'ordre du tableau définit le parcours : 0 -> 1 -> ... -> 10 -> retour au 0.
const BOARD_POSITIONS: Array[Vector2] = [
	Vector2(99, 578),   # 0 - départ / arrivée
	Vector2(132, 448),  # 1
	Vector2(194, 284),  # 2
	Vector2(360, 182),  # 3
	Vector2(512, 186),  # 4
	Vector2(628, 240),  # 5
	Vector2(722, 288),  # 6
	Vector2(734, 440),  # 7
	Vector2(676, 572),  # 8
	Vector2(458, 604),  # 9
	Vector2(232, 636),  # 10
]

## Nombre de pas pour boucler le parcours (10 cases + retour au départ).
const STEPS_TO_FINISH: int = 11

## Avancement logique du joueur (0 = sur le départ, 11 = a rejoint le départ).
var progress: int = 0
var is_moving: bool = false
var game_over: bool = false

@onready var player: Node2D = $Player
@onready var info_label: Label = $UI/InfoLabel
@onready var dice_label: Label = $UI/DiceLabel
@onready var roll_button: Button = $UI/RollButton

func _ready() -> void:
	randomize()
	player.position = BOARD_POSITIONS[0]
	roll_button.pressed.connect(_on_roll_pressed)
	_update_ui()

func _on_roll_pressed() -> void:
	if is_moving or game_over:
		return
	var roll: int = randi_range(1, 3)
	dice_label.text = "Dé : %d" % roll
	_advance(roll)

func _advance(steps: int) -> void:
	is_moving = true
	roll_button.disabled = true
	for i in range(steps):
		if progress >= STEPS_TO_FINISH:
			break
		progress += 1
		var target: Vector2 = BOARD_POSITIONS[progress % BOARD_POSITIONS.size()]
		var tween: Tween = create_tween()
		tween.tween_property(player, "position", target, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished
		_update_ui()
	is_moving = false
	if progress >= STEPS_TO_FINISH:
		_end_game()
	else:
		roll_button.disabled = false

func _end_game() -> void:
	game_over = true
	roll_button.disabled = true
	info_label.text = "Bravo ! Tu as rejoint le départ (0).\nPartie terminée."

func _update_ui() -> void:
	if game_over:
		return
	var current_case: int = progress % BOARD_POSITIONS.size()
	if progress >= STEPS_TO_FINISH:
		current_case = 0
	info_label.text = "Case actuelle : %d\nLance le dé (1 à 3) pour avancer." % current_case

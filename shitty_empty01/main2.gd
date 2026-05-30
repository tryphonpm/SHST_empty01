extends Node2D

const STEPS_TO_FINISH: int = 14   # 13 cases + retour au départ (0)
const BONUS_DISPLAY_DURATION: float = 2.0

var progress: int = 0
var is_moving: bool = false
var game_over: bool = false

@onready var board: Node2D       = $Board
@onready var player: Node2D      = $Player
@onready var info_label: Label   = $UI/InfoLabel
@onready var dice_label: Label   = $UI/DiceLabel
@onready var roll_button: Button = $UI/RollButton
@onready var bonus_popup: Panel  = $UI/BonusPopup

func _ready() -> void:
	randomize()
	player.position = board.BOARD_DATA[0]["pos"]
	roll_button.pressed.connect(_on_roll_pressed)
	bonus_popup.visible = false
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
		var idx: int = progress % board.BOARD_DATA.size()
		var target: Vector2 = board.BOARD_DATA[idx]["pos"]

		var tween: Tween = create_tween()
		tween.tween_property(player, "position", target, 0.25) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		await tween.finished

		_update_ui()

		# Vérifier la propriété bonus de la case d'arrivée (seulement sur la case finale du lancer)
		if i == steps - 1 and board.BOARD_DATA[idx]["bonus"]:
			await _show_bonus_popup()

	is_moving = false

	if progress >= STEPS_TO_FINISH:
		_end_game()
	else:
		roll_button.disabled = false

func _show_bonus_popup() -> void:
	bonus_popup.visible = true
	await get_tree().create_timer(BONUS_DISPLAY_DURATION).timeout
	bonus_popup.visible = false

func _end_game() -> void:
	game_over = true
	roll_button.disabled = true
	info_label.text = "Bravo ! Tu as rejoint le départ (0).\nPartie terminée."

func _update_ui() -> void:
	if game_over:
		return
	var current_case: int = progress % board.BOARD_DATA.size()
	if progress >= STEPS_TO_FINISH:
		current_case = 0
	info_label.text = "Case actuelle : %d\nLance le dé (1 à 3) pour avancer." % current_case

## Board 04 — généré depuis fond_04.md par generate_scene.py.
## NE PAS ÉDITER MANUELLEMENT.
## BoardBase expose BOARD_SETUP dans l'inspecteur (inspector_streets).
extends BoardBase

const BOARD_TYPE  := "urban"
const START_LABEL := "B::1"

const BG_COLOR    := Color("#1c2b0e")
const LABEL_COLOR := Color(1, 1, 1, 1)
const LABEL_SIZE  := 10
## Largeur de la zone de dessin du label, centrée sur le point central de l'emplacement.
## Doit être assez large pour le label le plus long (ex. 'B::20' = 5 chars).
const LABEL_WIDTH := 52.0

const BG_TEXTURE: Texture2D = preload("res://visuels/fond_04b.png")
## Position de l'image de fond alignée sur l'espace Excalidraw (calculée automatiquement).
const BG_RECT := Rect2(222.8, 65.5, 632.6, 631.4)

## Couleurs dynamiques par label (peuplées en phase de setup).
## Affecte la couleur du texte du label (les formes ne sont pas dessinées).
var shape_colors: Dictionary = {}

func set_shape_color(label: String, color: Color) -> void:
	shape_colors[label] = color
	queue_redraw()

## BOARD_SETUP — source unifiée des données du board.
## Générée depuis tmp/BOARDS_SETUP.json (boards_setup_json dans BOARD_CONFIGS).
## Remplace les anciennes const BOARD_DATA et STREETS.
## Structure : streets → rue → sidewalk → label → {type, pos, directions?}
const BOARD_SETUP: Dictionary = {
	"name": "Quartier Citadin",
	"scene": "res://game_04.tscn",
	"color": "#1c2b0e",
	"parcours": ["B::1", "B::3", "B::5", "B::7", "B::9", "B::11", "&::2", "@::2", "&::3", "B::13", "B::15", "B::17", "B::19"],
	"streets": {
		"A": {
			"name": "Alice",
			"odd_sidewalk": {
				"A::2": {
					"type": "address",
					"pos": Vector2(589.6, 684.9),
				},
				"A::4": {
					"type": "address",
					"pos": Vector2(589.6, 629.5),
				},
				"A::6": {
					"type": "address",
					"pos": Vector2(589.6, 602.3),
				},
				"A::8": {
					"type": "address",
					"pos": Vector2(589.6, 568.7),
				},
				"A::10": {
					"type": "address",
					"pos": Vector2(589.6, 537.9),
				},
				"A::12": {
					"type": "address",
					"pos": Vector2(589.6, 508.1),
				},
				"A::14": {
					"type": "address",
					"pos": Vector2(589.6, 481.0),
				},
				"&::4": {
					"type": "fork",
					"pos": Vector2(591.4, 442.1),
					"directions": [],
				},
				"@::3": {
					"type": "passage",
					"pos": Vector2(592.9, 402.2),
				},
			},
			"even_sidewalk": {
				"&::2": {
					"type": "fork",
					"pos": Vector2(478.1, 357.3),
					"directions": ["C::1", "B::13", "A::13"],
				},
				"A::1": {
					"type": "address",
					"pos": Vector2(478.4, 688.0),
				},
				"A::3": {
					"type": "address",
					"pos": Vector2(478.4, 660.8),
				},
				"A::5": {
					"type": "address",
					"pos": Vector2(478.4, 632.6),
				},
				"A::7": {
					"type": "address",
					"pos": Vector2(478.4, 605.6),
				},
				"A::9": {
					"type": "address",
					"pos": Vector2(478.4, 571.8),
				},
				"A::11": {
					"type": "address",
					"pos": Vector2(478.4, 544.7),
				},
				"A::13": {
					"type": "address",
					"pos": Vector2(478.4, 484.0),
				},
				"&::1": {
					"type": "fork",
					"pos": Vector2(478.5, 441.7),
					"directions": ["C::1", "B::13", "A::13"],
				},
				"@::1": {
					"type": "passage",
					"pos": Vector2(478.2, 400.0),
				},
			},
		},
		"B": {
			"name": "Barouch",
			"even_sidewalk": {
				"B::2": {
					"type": "address",
					"pos": Vector2(240.7, 439.6),
				},
				"B::4": {
					"type": "address",
					"pos": Vector2(274.6, 439.6),
				},
				"B::6": {
					"type": "address",
					"pos": Vector2(315.6, 439.6),
				},
				"B::8": {
					"type": "address",
					"pos": Vector2(352.9, 439.6),
				},
				"B::10": {
					"type": "address",
					"pos": Vector2(395.9, 439.6),
				},
				"B::12": {
					"type": "address",
					"pos": Vector2(447.1, 440.1),
				},
				"&::1": {
					"type": "fork",
					"pos": Vector2(478.5, 441.7),
					"directions": ["C::1", "B::13", "A::13"],
				},
				"@::4": {
					"type": "passage",
					"pos": Vector2(534.9, 442.7),
				},
				"&::4": {
					"type": "fork",
					"pos": Vector2(591.4, 442.1),
					"directions": [],
				},
				"B::14": {
					"type": "address",
					"pos": Vector2(623.2, 440.9),
				},
				"B::16": {
					"type": "address",
					"pos": Vector2(678.8, 440.9),
				},
				"B::18": {
					"type": "address",
					"pos": Vector2(721.5, 440.9),
				},
				"B::20": {
					"type": "address",
					"pos": Vector2(779.9, 440.9),
				},
			},
			"odd_sidewalk": {
				"B::1": {
					"type": "address",
					"pos": Vector2(239.8, 358.6),
				},
				"B::3": {
					"type": "address",
					"pos": Vector2(273.6, 358.6),
				},
				"B::5": {
					"type": "address",
					"pos": Vector2(314.6, 358.6),
				},
				"B::7": {
					"type": "address",
					"pos": Vector2(351.9, 358.6),
				},
				"B::9": {
					"type": "address",
					"pos": Vector2(392.9, 358.6),
				},
				"B::11": {
					"type": "address",
					"pos": Vector2(446.9, 358.6),
				},
				"&::2": {
					"type": "fork",
					"pos": Vector2(478.1, 357.3),
					"directions": ["C::1", "B::13", "A::13"],
				},
				"@::2": {
					"type": "passage",
					"pos": Vector2(531.6, 362.3),
				},
				"&::3": {
					"type": "fork",
					"pos": Vector2(583.1, 361.3),
					"directions": ["C::1", "B::13", "A::13"],
				},
				"B::13": {
					"type": "address",
					"pos": Vector2(616.1, 363.3),
				},
				"B::15": {
					"type": "address",
					"pos": Vector2(696.3, 363.3),
				},
				"B::17": {
					"type": "address",
					"pos": Vector2(736.0, 363.4),
				},
				"B::19": {
					"type": "address",
					"pos": Vector2(784.2, 363.4),
				},
			},
		},
		"C": {
			"name": "Caulaincourt",
			"even_sidewalk": {
				"&::3": {
					"type": "fork",
					"pos": Vector2(583.1, 361.3),
					"directions": ["C::1", "B::13", "A::13"],
				},
				"C::2": {
					"type": "address",
					"pos": Vector2(588.4, 334.8),
				},
				"C::4": {
					"type": "address",
					"pos": Vector2(596.5, 308.9),
				},
				"C::6": {
					"type": "address",
					"pos": Vector2(615.0, 248.8),
				},
				"C::8": {
					"type": "address",
					"pos": Vector2(630.3, 200.4),
				},
				"C::10": {
					"type": "address",
					"pos": Vector2(651.5, 124.0),
				},
			},
			"odd_sidewalk": {
				"&::2": {
					"type": "fork",
					"pos": Vector2(478.1, 357.3),
					"directions": ["C::1", "B::13", "A::13"],
				},
				"C::1": {
					"type": "address",
					"pos": Vector2(491.2, 330.8),
				},
				"C::3": {
					"type": "address",
					"pos": Vector2(499.3, 305.4),
				},
				"C::5": {
					"type": "address",
					"pos": Vector2(507.8, 278.5),
				},
				"C::7": {
					"type": "address",
					"pos": Vector2(523.5, 228.4),
				},
				"C::9": {
					"type": "address",
					"pos": Vector2(572.5, 80.0),
				},
			},
		},
	},
}

## PLAYERS — état initial des joueurs (position de départ, domicile, couleur).
## Source : players_json défini dans BOARD_CONFIGS.
## game_urban.gd en fait une copie mutable (var players) mise à jour à chaque tour.
const PLAYERS: Dictionary = {
	"1": {
		"name": "Danielle",
		"color": "red",
		"current_position": {
			"street": "A",
			"sidewalk": "even",
			"num": 1,
			"direction": "up",
			"address_fork": "",
			"address_passage": "",
		},
		"home": "A::1",
	},
	"2": {
		"name": "Pacha",
		"color": "blue",
		"current_position": {
			"street": "B",
			"sidewalk": "even",
			"num": 4,
			"direction": "up",
			"address_fork": "",
			"address_passage": "",
		},
		"home": "B::4",
	},
}

const SHAPES := [
	{"label": "&::1", "type": "rectangle", "cx": 478.5, "cy": 441.7},
	{"label": "&::2", "type": "rectangle", "cx": 478.1, "cy": 357.3},
	{"label": "&::3", "type": "rectangle", "cx": 583.1, "cy": 361.3},
	{"label": "&::4", "type": "rectangle", "cx": 591.4, "cy": 442.1},
	{"label": "A::1", "type": "rectangle", "cx": 478.4, "cy": 688.0},
	{"label": "A::3", "type": "rectangle", "cx": 478.4, "cy": 660.8},
	{"label": "A::5", "type": "rectangle", "cx": 478.4, "cy": 632.6},
	{"label": "A::7", "type": "rectangle", "cx": 478.4, "cy": 605.6},
	{"label": "A::9", "type": "rectangle", "cx": 478.4, "cy": 571.8},
	{"label": "A::11", "type": "rectangle", "cx": 478.4, "cy": 544.7},
	{"label": "A::13", "type": "rectangle", "cx": 478.4, "cy": 484.0},
	{"label": "A::2", "type": "rectangle", "cx": 589.6, "cy": 684.9},
	{"label": "A::4", "type": "rectangle", "cx": 589.6, "cy": 629.5},
	{"label": "A::6", "type": "rectangle", "cx": 589.6, "cy": 602.3},
	{"label": "A::8", "type": "rectangle", "cx": 589.6, "cy": 568.7},
	{"label": "A::12", "type": "rectangle", "cx": 589.6, "cy": 508.1},
	{"label": "A::14", "type": "rectangle", "cx": 589.6, "cy": 481.0},
	{"label": "A::10", "type": "rectangle", "cx": 589.6, "cy": 537.9},
	{"label": "C::2", "type": "rectangle", "cx": 588.4, "cy": 334.8},
	{"label": "C::4", "type": "rectangle", "cx": 596.5, "cy": 308.9},
	{"label": "C::6", "type": "rectangle", "cx": 615.0, "cy": 248.8},
	{"label": "C::8", "type": "rectangle", "cx": 630.3, "cy": 200.4},
	{"label": "C::10", "type": "rectangle", "cx": 651.5, "cy": 124.0},
	{"label": "C::1", "type": "rectangle", "cx": 491.2, "cy": 330.8},
	{"label": "C::3", "type": "rectangle", "cx": 499.3, "cy": 305.4},
	{"label": "C::5", "type": "rectangle", "cx": 507.8, "cy": 278.5},
	{"label": "C::7", "type": "rectangle", "cx": 523.5, "cy": 228.4},
	{"label": "C::9", "type": "rectangle", "cx": 572.5, "cy": 80.0},
	{"label": "B::14", "type": "rectangle", "cx": 623.2, "cy": 440.9},
	{"label": "B::16", "type": "rectangle", "cx": 678.8, "cy": 440.9},
	{"label": "B::18", "type": "rectangle", "cx": 721.5, "cy": 440.9},
	{"label": "B::20", "type": "rectangle", "cx": 779.9, "cy": 440.9},
	{"label": "B::13", "type": "rectangle", "cx": 616.1, "cy": 363.3},
	{"label": "B::15", "type": "rectangle", "cx": 696.3, "cy": 363.3},
	{"label": "B::17", "type": "rectangle", "cx": 736.0, "cy": 363.4},
	{"label": "B::19", "type": "rectangle", "cx": 784.2, "cy": 363.4},
	{"label": "B::3", "type": "rectangle", "cx": 273.6, "cy": 358.6},
	{"label": "B::5", "type": "rectangle", "cx": 314.6, "cy": 358.6},
	{"label": "B::7", "type": "rectangle", "cx": 351.9, "cy": 358.6},
	{"label": "B::9", "type": "rectangle", "cx": 392.9, "cy": 358.6},
	{"label": "B::11", "type": "rectangle", "cx": 446.9, "cy": 358.6},
	{"label": "B::1", "type": "rectangle", "cx": 239.8, "cy": 358.6},
	{"label": "B::4", "type": "rectangle", "cx": 274.6, "cy": 439.6},
	{"label": "B::6", "type": "rectangle", "cx": 315.6, "cy": 439.6},
	{"label": "B::8", "type": "rectangle", "cx": 352.9, "cy": 439.6},
	{"label": "B::10", "type": "rectangle", "cx": 395.9, "cy": 439.6},
	{"label": "B::12", "type": "rectangle", "cx": 447.1, "cy": 440.1},
	{"label": "B::2", "type": "rectangle", "cx": 240.7, "cy": 439.6},
	{"label": "@::1", "type": "rectangle", "cx": 478.2, "cy": 400.0},
	{"label": "@::4", "type": "rectangle", "cx": 534.9, "cy": 442.7},
	{"label": "@::2", "type": "rectangle", "cx": 531.6, "cy": 362.3},
	{"label": "@::3", "type": "rectangle", "cx": 592.9, "cy": 402.2},
]

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1024, 768), BG_COLOR)
	draw_texture_rect(BG_TEXTURE, BG_RECT, false)
	# Les rectangles Excalidraw ne sont PAS dessinés (emplacements transparents).
	# Seuls les labels sont affichés, centrés sur le point central de chaque emplacement.
	# shape_colors permet de personnaliser la couleur d'un label individuel (via setup).
	for sh in SHAPES:
		var color: Color = shape_colors.get(sh.label, LABEL_COLOR)
		draw_string(
			ThemeDB.fallback_font,
			Vector2(sh.cx - LABEL_WIDTH * 0.5, sh.cy + LABEL_SIZE * 0.5),
			sh.label, HORIZONTAL_ALIGNMENT_CENTER, LABEL_WIDTH, LABEL_SIZE, color
		)

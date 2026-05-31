## Classe de base pour les boards urbains générés (board_XX.gd).
##
## Expose la const BOARD_SETUP (définie dans la classe dérivée générée) sous
## forme de Resources BoardStreet / BoardEmplacement dans l'inspecteur Godot.
## Pendant la partie, l'onglet Remote de l'inspecteur affiche la hiérarchie
## complète : streets → sidewalks → emplacements (label, type, pos, parcours).
class_name BoardBase
extends Node2D

@export_group("Board Setup")
## Rues du board, peuplées depuis BOARD_SETUP à _ready().
## Non typée Array[BoardStreet] pour compatibilité linter cross-fichier.
@export var inspector_streets: Array = []

func _ready() -> void:
	_populate_inspector_data()

func _populate_inspector_data() -> void:
	inspector_streets.clear()
	var raw_setup: Variant = self.get("BOARD_SETUP")
	if raw_setup == null:
		push_warning("BoardBase: BOARD_SETUP introuvable dans %s" % get_script().resource_path)
		return
	var setup: Dictionary   = raw_setup as Dictionary
	var streets: Dictionary = setup.get("streets", {}) as Dictionary

	for sk: String in streets:
		var sd: Dictionary = streets[sk] as Dictionary
		var street_res: Resource = ClassDB.instantiate(&"BoardStreet") \
			if ClassDB.class_exists(&"BoardStreet") \
			else load("res://board_street.gd").new()
		street_res.set("street_key",  sk)
		street_res.set("street_name", sd.get("name", ""))

		for sw_key: String in ["even_sidewalk", "odd_sidewalk"]:
			if not sd.has(sw_key):
				continue
			var sw: Dictionary = sd[sw_key] as Dictionary
			var empl_list: Array = []
			for lbl: String in sw:
				var entry: Dictionary = sw[lbl] as Dictionary
				var empl: Resource = ClassDB.instantiate(&"BoardEmplacement") \
					if ClassDB.class_exists(&"BoardEmplacement") \
					else load("res://board_emplacement.gd").new()
				empl.set("label", lbl)
				empl.set("type",  entry.get("type", ""))
				empl.set("pos",   entry.get("pos",  Vector2.ZERO))
				var raw_p: Variant = entry.get("parcours", [])
				if raw_p is Array:
					empl.set("parcours", raw_p)
				empl_list.append(empl)
			street_res.set(sw_key, empl_list)

		inspector_streets.append(street_res)

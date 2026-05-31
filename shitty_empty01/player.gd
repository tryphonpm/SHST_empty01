## Script du node Player pour le board urban.
##
## Expose les données du joueur actif (issues de board.PLAYERS) comme propriétés
## inspectables via l'inspecteur Godot. Pendant la partie, l'onglet Remote de
## l'inspecteur affiche les valeurs en temps réel après chaque coup de dé.
##
## Initialisation : sync_from_dict(id, players[id]) appelé depuis game_urban.gd.
extends Node2D

@export_group("Identité")
@export var player_id:    String = ""
@export var player_name:  String = ""
@export var player_color: String = ""
@export var home:         String = ""

@export_group("Position courante")
@export var pos_street:           String = ""
@export var pos_num:              int    = 0
@export var pos_direction:        String = ""
@export var pos_address_fork:     String = ""
@export var pos_address_passage:  String = ""

## Synchronise toutes les propriétés depuis un dict issu de board.PLAYERS[id].
## Appelé depuis game_urban.gd à chaque déplacement ou choix de carrefour.
func sync_from_dict(pid: String, data: Dictionary) -> void:
	player_id    = pid
	player_name  = data.get("name",  "")
	player_color = data.get("color", "")
	home         = data.get("home",  "")
	var cp: Dictionary = data.get("current_position", {})
	pos_street          = str(cp.get("street",           ""))
	pos_num             = int(cp.get("num",              0))
	pos_direction       = str(cp.get("direction",        ""))
	pos_address_fork    = str(cp.get("address_fork",     ""))
	pos_address_passage = str(cp.get("address_passage",  ""))

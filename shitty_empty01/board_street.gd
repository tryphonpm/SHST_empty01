## Rue d'un board urban avec ses deux trottoirs d'emplacements ordonnés.
## Exposé dans l'inspecteur via BoardBase.inspector_streets.
class_name BoardStreet
extends Resource

@export var street_key:    String = ""
@export var street_name:   String = ""
## Emplacements (BoardEmplacement) — non typés pour compatibilité linter cross-fichier.
@export var even_sidewalk: Array = []
@export var odd_sidewalk:  Array = []

## Emplacement d'un board urban : adresse, fork ou passage.
## Exposé dans l'inspecteur via les sidewalks de BoardStreet.
class_name BoardEmplacement
extends Resource

@export var label: String = ""
@export var type:  String = ""
@export var pos:   Vector2 = Vector2.ZERO
@export var parcours: Array = []

# CLAUDE.md — SHITTY STREET

Documentation de référence pour tout agent IA (ou développeur) intervenant sur ce projet.
À mettre à jour à chaque évolution structurelle.

---

## Description du projet

Jeu de plateau au tour par tour, 1 joueur, développé sous **Godot 4.4.1** (GDScript).
Le joueur (triangle isocèle bleu) parcourt un circuit de cases numérotées en lançant un dé (1–3).
La partie se termine quand le joueur rejoint la case de départ `0`.
Certaines cases déclenchent des effets (actuellement : popup BONUS pendant 2 secondes).

---

## Stack technique

| Composant | Technologie |
|---|---|
| Moteur de jeu | Godot 4.4.1 stable (`mobile` renderer) |
| Langage jeu | GDScript (typage statique) |
| Génération boards | Python 3.13 + `lzstring` (pip) |
| Source des boards | Obsidian + plugin Excalidraw (fichiers `.md` compressés) |
| Viewport | 1024 × 768, stretch `canvas_items / keep` |
| OS dev | Windows 11 / PowerShell |

---

## Structure des dossiers

```
SHITTY_STREET_empty01/
├── .cursorrules               ← règles IA pour Cursor
├── CLAUDE.md                  ← ce fichier
├── generate_scene.py          ← pipeline Python (Excalidraw → Godot)
├── extract_excali.py          ← utilitaire debug (lecture Excalidraw)
├── visuels/
│   ├── fond_02.md             ← dessin Excalidraw du Board Classique
│   ├── fond_03.md             ← dessin Excalidraw du Board Nouveau
│   └── fond_01.png            ← image de référence originale (non utilisée)
└── shitty_empty01/            ← projet Godot
    ├── project.godot          ← config projet (main_scene = menu.tscn)
    ├── menu.tscn              ← scène principale : sélection de board
    ├── menu.gd                ← script du menu
    ├── game.gd                ← logique de jeu partagée (tous boards)
    ├── game_02.tscn           ← scène Board Classique  ┐ générés
    ├── game_03.tscn           ← scène Board Nouveau    ┘ par Python
    ├── board_02.gd            ← données + rendu Board 02 ┐ NE PAS
    └── board_03.gd            ← données + rendu Board 03 ┘ ÉDITER
```

---

## Pipeline de génération (Excalidraw → Godot)

```
visuels/fond_XX.md
   │  compressed-json (LZ-string)
   ▼
generate_scene.py
   │  décompresse → extrait formes/labels → calcule transform → génère GDScript
   ▼
shitty_empty01/board_XX.gd   (BOARD_DATA + SHAPES + _draw())
shitty_empty01/game_XX.tscn  (scène : Board + Player + UI)
shitty_empty01/game.gd       (logique partagée, générée une seule fois)
```

**Commande de regénération (PowerShell) :**
```powershell
$env:PYTHONIOENCODING='utf-8'; python generate_scene.py
```

---

## Structure de données BOARD_DATA

Chaque case du parcours est un `Dictionary` extensible dans `board_XX.gd` :

```gdscript
const BOARD_DATA := [
    {"pos": Vector2(109.8, 546.8), "bonus": false, "forks": []},         # 0 — départ/arrivée
    {"pos": Vector2(145.4, 396.2), "bonus": false, "forks": []},         # 1
    {"pos": Vector2(222.3, 200.5), "bonus": true,  "forks": []},         # 2 ← BONUS
    ...
    {"pos": Vector2(443.8, 310.1), "bonus": false, "forks": [6, 11]},    # 5 ← carrefour
    ...
]
```

| Clé | Type | Description |
|---|---|---|
| `pos` | `Vector2` | Position Godot de la case (calculée depuis Excalidraw) |
| `bonus` | `bool` | Déclenche la popup BONUS 2 s à l'arrivée |
| `forks` | `Array[int]` | Vide = linéaire. Non vide = carrefour : popup de choix de direction |
| *(futures)* | *…* | Ajouter dans `PROPERTY_DEFAULTS` et `CASE_PROPERTIES` |

---

## Boards disponibles

| ID | Nom | Source | Couleur fond | Cases | Bonus |
|---|---|---|---|---|---|
| 02 | Board Classique | `fond_02.md` | `#ff1450` (rose) | 14 (0–13) | 2, 5, 9, 10 |
| 03 | Board Nouveau | `fond_03.md` | `#1a3a5c` (bleu) | 14 (0–13) | aucun |

---

## Phase de setup (`game.gd`)

Avant chaque partie, `_ready()` appelle `_run_setup()` (bouton désactivé pendant ce temps).

```
_run_setup()
   └─ for step in _get_setup_steps(): await step.call()
         └─ _setup_colored_positions()   ← setup #1 : 3 cases colorisées en marron
         # └─ _setup_future_feature()    ← setup #2 : décommenter pour activer
```

### Ajouter une étape de setup
1. Écrire `func _setup_ma_feature() -> void:` dans `game.gd`
2. Ajouter `_setup_ma_feature,` dans `_get_setup_steps()`
3. La fonction peut appeler `board.set_shape_color(label, color)` ou toute autre modification

### `board.set_shape_color(label, color)`
Peuple `board.shape_colors[label]` et appelle `queue_redraw()`.  
`_draw()` lit `shape_colors.get(sh.label, SHAPE_COLOR)` pour chaque forme.  
Clé = label String de la case (ex. `"3"`, `"11"`).

---

## Logique de jeu (`game.gd`)

Variables d'état : `current_idx` (case courante), `has_started`, `is_moving`, `game_over`.

1. `_ready()` : place le joueur sur `BOARD_DATA[0]["pos"]`, exécute `_run_setup()`
2. Bouton **Lancer le dé** → `randi_range(1, 3)` → `_advance(roll)`, passe `has_started = true`
3. `_advance()` : boucle sur le nombre de pas — `current_idx = (current_idx + 1) % size`
   - Si `current_idx == 0` → fin de partie
   - Sur la dernière case du lancer, vérifie `bonus` puis `forks`
4. `_show_bonus_popup()` : affiche `UI/BonusPopup` pendant 2 s (auto-fermeture)
5. `_show_fork_popup(forks)` :
   - Génère dynamiquement un bouton par direction (indices dans `forks`)
   - Attend le signal `fork_chosen(case_idx)` émis au clic
   - Déplace le joueur vers `case_idx`, met à jour `current_idx`
6. Fin de partie : `current_idx == 0` après `has_started` → message de victoire
7. Bouton **← Menu** → `get_tree().change_scene_to_file("res://menu.tscn")`

---

## Recettes courantes

### Ajouter un 3ème board
1. Créer le dessin dans Obsidian/Excalidraw → sauvegarder en `visuels/fond_04.md`
2. Ajouter une entrée dans `BOARD_CONFIGS` (`generate_scene.py`)
3. Relancer `generate_scene.py`
4. Ajouter l'entrée dans `BOARDS` (`menu.gd`)

### Ajouter une propriété de case (ex: `malus`)
1. Ajouter `"malus": False` dans `PROPERTY_DEFAULTS` (`generate_scene.py`)
2. Renseigner les cases concernées dans `case_properties` du board voulu
3. Relancer `generate_scene.py` → `board_XX.gd` contient la nouvelle clé
4. Exploiter `board.BOARD_DATA[idx]["malus"]` dans `game.gd`

### Modifier le parcours d'un board
1. Ouvrir `visuels/fond_XX.md` dans Obsidian (vue Excalidraw)
2. Modifier les formes / repositionner les cases
3. Relancer `generate_scene.py`

---

## Conventions de code

### GDScript
- Typage statique systématique (`var x: int`, `func f() -> void`)
- Pas d'inférence `:=` sur des éléments extraits de tableaux non typés → `var b: Dictionary = arr[i]`
- `@onready` pour tous les nœuds référencés
- Constantes en `SCREAMING_SNAKE_CASE`
- Séparation claire : `board_XX.gd` = données/rendu, `game.gd` = logique

### Python (`generate_scene.py`)
- `BOARD_CONFIGS` = unique point de configuration game-design
- `PROPERTY_DEFAULTS` = liste exhaustive des propriétés connues avec leur valeur par défaut
- Les coordonnées ne sont jamais hardcodées : elles viennent du JSON Excalidraw

---

## Historique des décisions (ADR succinct)

| # | Décision | Raison |
|---|---|---|
| 1 | Board dessiné en Excalidraw (`.md`) plutôt qu'image PNG | Coordonnées exactes, types de formes explicites, mise à jour sans re-détection de pixels |
| 2 | `BOARD_DATA` = tableau de `Dictionary` extensible | Permet d'ajouter des propriétés sans casser l'existant |
| 3 | `game.gd` partagé entre tous les boards | DRY — une seule implémentation de la logique de jeu |
| 4 | `current_idx` à la place d'un compteur `progress` | Nécessaire pour les carrefours (sauts non linéaires dans le parcours) |
| 5 | Signal `fork_chosen` + `await` pour la popup de carrefour | Pattern Godot 4 idiomatique pour bloquer l'exécution en attendant un choix UI |
| 6 | Menu de sélection de board comme scène principale | Extensible à N boards sans modifier `project.godot` |
| 7 | Phase setup via `_get_setup_steps() -> Array[Callable]` | Liste explicite et ordonnée, chaque étape est une fonction indépendante, `await` natif |
| 8 | `shape_colors` dict + `set_shape_color()` dans `board_XX.gd` | Séparation données statiques (const SHAPES) / état dynamique (var shape_colors) |

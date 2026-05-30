# CLAUDE.md — SHITTY STREET

Documentation de référence pour tout agent IA (ou développeur) intervenant sur ce projet.
À mettre à jour à chaque évolution structurelle.

---

## Description du projet

Jeu de plateau au tour par tour, 1 joueur, développé sous **Godot 4.4.1** (GDScript).
Le joueur (triangle isocèle bleu) parcourt un circuit de cases en lançant un dé (1–3).
Il existe deux paradigmes de board : **classic** et **urban** (voir ci-dessous).

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
├── visuels/
│   ├── fond_02.md             ← dessin Excalidraw du Board Classique (classic)
│   ├── fond_03.md             ← dessin Excalidraw du Board Nouveau   (classic)
│   ├── fond_04.md             ← dessin Excalidraw du Quartier Citadin (urban)
│   └── passage_pieton.svg     ← icône de marqueur de carrefour
└── shitty_empty01/            ← projet Godot
    ├── project.godot          ← config projet (main_scene = menu.tscn)
    ├── menu.tscn              ← scène principale : sélection de board
    ├── menu.gd                ← script du menu
    ├── game.gd                ← logique classic (game_02, game_03)
    ├── game_urban.gd          ← logique urban  (game_04, …)
    ├── game_02.tscn           ┐
    ├── game_03.tscn           │ générés par generate_scene.py
    ├── game_04.tscn           ┘ NE PAS ÉDITER MANUELLEMENT
    ├── board_02.gd            ┐
    ├── board_03.gd            │ générés par generate_scene.py
    └── board_04.gd            ┘ NE PAS ÉDITER MANUELLEMENT
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
```

**Commande de regénération (PowerShell) :**
```powershell
$env:PYTHONIOENCODING='utf-8'; python generate_scene.py
```

Si un fichier `.md` est absent, le board correspondant est **ignoré avec un avertissement**
(sans planter le script).

---

## Deux paradigmes de board

### `board_type: "classic"` (game_02, game_03)

- Labels = entiers (`0`, `1`, …)
- `BOARD_DATA` = `Array` de `Dictionary`, indexé par position
- Parcours = circulaire, `(current_idx + 1) % size` ; retour sur `#0` = fin de partie
- Forks = `Array[int]` d'indices vers des cases de destination
- Script de jeu : `game.gd`

### `board_type: "urban"` (game_04, …) ← **nouvelle norme**

- Labels = chaînes `"X::n"` (ex. `"B::1"`, `"&::2"`, `"@::3"`)
- `BOARD_DATA` = `Dictionary` keyed par label string
- Parcours = liste ordonnée explicite `PARCOURS: Array[String]` définie dans `BOARD_CONFIGS`
- Fin de partie = atteindre/dépasser le dernier label du PARCOURS (non plus retour à `#0`)
- Forks = `Array[String]` de labels de destination
- Script de jeu : `game_urban.gd`

---

## Structure de données BOARD_DATA

### Classic
```gdscript
const BOARD_DATA := [
    {"pos": Vector2(109.8, 546.8), "bonus": false, "forks": []},         # 0 — départ/arrivée
    {"pos": Vector2(145.4, 396.2), "bonus": false, "forks": []},         # 1
    {"pos": Vector2(443.8, 310.1), "bonus": false, "forks": [6, 11]},    # 5 ← carrefour
    ...
]
```

### Urban
```gdscript
const BOARD_DATA: Dictionary = {
    "B::1":  {"pos": Vector2(239.8, 358.6), "type": "address", "street": "B", "num": 1,
              "rx": 7.6, "ry": 3.8, "bonus": false, "forks": []},
    "&::2":  {"pos": Vector2(478.1, 357.3), "type": "fork",    "street": "&", "num": 2,
              "rx": 5.6, "ry": 3.8, "bonus": false, "forks": ["C::1", "B::13", "A::13"]},
    "@::2":  {"pos": Vector2(531.6, 362.3), "type": "passage", "street": "@", "num": 2,
              "rx": 5.6, "ry": 3.8, "bonus": false, "forks": []},
    ...
}

const PARCOURS: Array[String] = [
    "B::1", "B::3", "B::5", "B::7", "B::9", "B::11",
    "&::2", "@::2", "&::3",
    "B::13", "B::15", "B::17", "B::19",
]
```

**Types d'emplacements urban** (inférés automatiquement depuis le préfixe du label) :

| Préfixe | Type | Description |
|---|---|---|
| `@` | `passage` | Passage (ex. piétons) — position de transit |
| `&` | `fork` | Carrefour — déclenche un choix de direction |
| toute lettre (`A`–`Z`) | `address` | Adresse de rue |

**Clés communes aux deux paradigmes** dans chaque entrée de BOARD_DATA :

| Clé | Classic | Urban | Description |
|---|---|---|---|
| `pos` | `Vector2` | `Vector2` | Position Godot |
| `bonus` | `bool` | `bool` | Déclenche popup BONUS 2 s |
| `forks` | `Array[int]` | `Array[String]` | Vide = linéaire ; non vide = carrefour |
| `type` | — | `String` | `"address"` / `"fork"` / `"passage"` |
| `street` | — | `String` | Lettre de la rue (ex. `"B"`, `"&"`) |
| `num` | — | `int` | Nombre du label |
| `rx`, `ry` | — | `float` | Demi-dimensions du rectangle (pour marqueurs) |

---

## Boards disponibles

| ID | Nom | Type | Source | Couleur fond |
|---|---|---|---|---|
| 02 | Board Classique | classic | `fond_02.md` | `#ff1450` (rose) |
| 03 | Board Nouveau | classic | `fond_03.md` | `#1a3a5c` (bleu) |
| 04 | Quartier Citadin | urban | `fond_04.md` | `#1c2b0e` (vert nuit) |

---

## Logique de jeu — Classic (`game.gd`)

Variables d'état : `current_idx`, `has_started`, `is_moving`, `game_over`.

1. `_ready()` → place joueur sur `BOARD_DATA[0]["pos"]`, `_run_setup()`
2. Dé → `randi_range(1, 3)` → `_advance(roll)`, `has_started = true`
3. `_advance(steps)` :
   - **Fork départ** : si `BOARD_DATA[current_idx].forks` non vide → popup, choix consomme 1 pas
   - **Boucle** `while remaining > 0` : `current_idx = (current_idx + 1) % size` ; fork transit si `remaining > 0`
   - **Fin** : `current_idx == 0` après `has_started`
4. Fork popup → signal `fork_chosen(case_idx: int)` → `current_idx = case_idx`

---

## Logique de jeu — Urban (`game_urban.gd`)

Variables d'état : `parcours_idx`, `current_label`, `is_moving`, `game_over`.

1. `_ready()` → `parcours_idx = 0`, `current_label = PARCOURS[0]`, `_run_setup()`
2. Dé → `randi_range(1, 3)` → `_advance(roll)`
3. `_advance(steps)` :
   - **Fork départ** : si `BOARD_DATA[current_label]["type"] == "fork"` → `_resolve_fork()`, choix consomme 1 pas
   - **Boucle** `while remaining > 0` : `parcours_idx += 1` ; si dépassement → `_end_game()`
   - **Fork transit** : si fork ET `remaining > 0` → `_resolve_fork()`
   - **Fin** : `parcours_idx >= PARCOURS.size()` = fin de parcours
4. `_resolve_fork(fork_opts)` : sélectionne automatiquement le premier label de `fork_opts` présent dans `PARCOURS` après la position courante. **TODO** : remplacer par popup interactive.
5. `_jump_to_label(label, parcours)` : saute vers un label, met à jour `parcours_idx`

**Tableau récapitulatif fork (identique pour classic et urban) :**

| Moment | Comportement | Coût |
|---|---|---|
| Case de départ du tour | Résolution AVANT tout mouvement | 1 pas |
| Transit (`remaining > 0`) | Résolution PENDANT le mouvement | 1 pas |
| Case d'arrivée finale (`remaining == 0`) | **Aucun** — le joueur s'arrête normalement | — |

---

## Phase de setup

Avant chaque partie, `_ready()` appelle `_run_setup()` (bouton désactivé pendant ce temps).

```
_run_setup()
   └─ for step in _get_setup_steps(): await step.call()
```

**Classic (`game.gd`)** :
- `_setup_colored_positions()` — 3 cases colorisées aléatoirement en marron
- `_setup_fork_markers()` — icône SVG près de chaque case fork

**Urban (`game_urban.gd`)** :
- `_setup_fork_markers()` — icône SVG près de chaque emplacement de type "fork"

### Ajouter une étape de setup
1. Écrire `func _setup_ma_feature() -> void:` dans le script de jeu concerné
2. Ajouter `_setup_ma_feature,` dans `_get_setup_steps()`

### `board.set_shape_color(label, color)`
Peuple `board.shape_colors[label]` et appelle `queue_redraw()`.  
`_draw()` lit `shape_colors.get(sh.label, SHAPE_COLOR)` pour chaque forme.  
Clé = label String de la case (ex. `"3"` pour classic, `"B::7"` pour urban).

---

## BOARD_CONFIGS dans `generate_scene.py`

```python
{
    "id":          "04",            # suffixe des fichiers générés
    "name":        "Quartier Citadin",
    "md_file":     "fond_04.md",    # source Excalidraw
    "board_type":  "urban",         # "classic" | "urban"
    "bg_color":    "#1c2b0e",
    "start_label": "B::1",          # (urban) premier label du parcours
    "parcours": ["B::1", ...],      # (urban) séquence ordonnée du chemin
    "label_properties": {           # (urban) propriétés par label
        "&::2": {"forks": ["C::1", "B::13", "A::13"]},
    },
    # classic uniquement :
    # "case_properties": { 5: {"forks": [6, 11]} }
}
```

---

## Recettes courantes

### Ajouter un board urban
1. Créer le dessin dans Obsidian/Excalidraw → sauvegarder en `visuels/fond_XX.md`
   - Formes : **rectangles** avec labels `"X::n"` (ex. `"B::1"`, `"&::2"`)
2. Ajouter une entrée `board_type: "urban"` dans `BOARD_CONFIGS` avec `parcours` et `label_properties`
3. Relancer `generate_scene.py`
4. Ajouter l'entrée dans `BOARDS` (`menu.gd`)

### Ajouter un board classic
1. Créer le dessin → cercles/ellipses numérotés de 0 à N
2. Ajouter entrée `board_type: "classic"` dans `BOARD_CONFIGS`
3. Relancer `generate_scene.py` + ajouter dans `BOARDS` (`menu.gd`)

### Activer la popup de fork interactive (urban)
Remplacer `_resolve_fork()` dans `game_urban.gd` par :
```gdscript
func _resolve_fork(fork_opts: Array, parcours: Array) -> String:
    for child in fork_btn_container.get_children():
        child.queue_free()
    for opt in fork_opts:
        var btn := Button.new()
        btn.text = "→ %s" % opt
        btn.pressed.connect(func(): fork_chosen.emit(opt as String))
        fork_btn_container.add_child(btn)
    fork_popup.visible = true
    var chosen: String = await fork_chosen
    fork_popup.visible = false
    return chosen
```

---

## Conventions de code

### GDScript
- Typage statique systématique (`var x: int`, `func f() -> void`)
- `@onready` pour tous les nœuds référencés ; pas de `get_node()`
- Pas d'inférence `:=` sur des éléments extraits de tableaux non typés → `var b: Dictionary = arr[i]`
- Constantes en `SCREAMING_SNAKE_CASE`, variables en `snake_case`
- Séparation stricte : `board_XX.gd` = données/rendu, `game*.gd` = logique

### Python (`generate_scene.py`)
- `BOARD_CONFIGS` = unique point de configuration game-design
- Les coordonnées viennent toujours d'Excalidraw — jamais hardcodées
- Utiliser `$env:PYTHONIOENCODING='utf-8'` avant le script (PowerShell Windows)

---

## Historique des décisions (ADR succinct)

| # | Décision | Raison |
|---|---|---|
| 1 | Board dessiné en Excalidraw (`.md`) | Coordonnées exactes, types de formes explicites |
| 2 | `BOARD_DATA` = `Dictionary` extensible | Permet d'ajouter des propriétés sans casser l'existant |
| 3 | `game.gd` partagé pour les boards classic | DRY — une seule implémentation |
| 4 | `current_idx` (classic) | Nécessaire pour les sauts non linéaires (forks) |
| 5 | Signal `fork_chosen` + `await` | Pattern Godot 4 idiomatique pour bloquer sur un choix UI |
| 5b | `while remaining > 0` | Intercepter un fork à n'importe quelle étape du mouvement |
| 6 | Menu de sélection de board | Extensible à N boards sans modifier `project.godot` |
| 7 | `_get_setup_steps() -> Array[Callable]` | Liste explicite, chaque étape indépendante, `await` natif |
| 8 | `board_type: "urban"` + `game_urban.gd` | Nouvelle norme : labels `"X::n"`, PARCOURS explicite, fin au dernier label |
| 9 | `_resolve_fork()` auto (urban) | Temporaire : sélectionne B::13 naturellement (seul label de fork présent dans PARCOURS) |

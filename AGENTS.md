# AGENTS.md

Repères pour toute IA (et tout humain) qui travaille sur ce dépôt. Ce sont des **suggestions** pour éviter les conflits et garder le code lisible, pas un règlement : en cas de doute ou de bonne raison de faire autrement, on s'écarte de ce fichier et on le dit à l'équipe. Moins de 48h : on fait simple, lisible, qui marche.

## Contexte

* Jeu d'évasion asymétrique à 2 joueurs, hackathon Le Rebours (rendu vendredi 23/10 à 10h).
* Godot **4.7.2** standard (pas .NET), rendu Forward Plus, **GDScript uniquement**, jeu en 3D.
* Les développeurs sont surtout sur Windows, un sur Linux. Cible de build : **Windows**.
* Autoloads existants : `FmodManager` (son) et `ArduinoManager` (série).

## À éviter (ce qui casse vraiment des choses)

* Modifier `addons/` et `Scripts/serial_tcp_simu.gd` : le script série en dépend.
* Remplacer les banques de `FMOD Banks/` : c'est la personne du son qui les dépose.
* Éditer la même scène `.tscn` à deux en même temps : c'est la première source de conflits Git. Un message dans le chat ("j'ouvre Player.tscn") suffit.
* Changer des réglages existants de `project.godot` au passage. Y ajouter un autoload ou une action d'entrée est normal, mieux vaut le faire dans un commit à part et le mentionner.

## Répartition du travail (suggestion)

Une zone a un référent qui la connaît, pas un propriétaire exclusif. Toute personne peut y toucher, mais prévient le référent avant un gros changement.

| Zone | Référent suggéré |
|---|---|
| `ArduinoManager`, branchement réel des capteurs | Adrien |
| `ControllerInput`, clavier de remplacement, joueur (`Scripts/Player/`, `Scenes/Player.tscn`) | Alexandre |
| Niveaux (`Scenes/Levels/`), agencement des salles | Jalis |
| Pièges (`Scenes/Traps/`) | la personne qui en implémente un |
| Branchement du son dans Godot | David |
| Sons et banques FMOD | Florian, Anis |
| `project.godot`, `GameScene.tscn` | David (chef de projet) |

Pour limiter les conflits sur les scènes : une scène par niveau et par piège, `GameScene` n'instancie que le niveau courant, et on ajoute un piège dans un niveau en l'instanciant plutôt qu'en modifiant sa scène.

## Architecture (suggestions)

* **Une scène, un script, une responsabilité.** Au-delà de 150 lignes, un script fait probablement trop de choses.
* **Communication par signaux.** Un nœud connaît ses enfants, rarement ses parents ni ses voisins : éviter `get_node("../../..")`.
* **Pas de logique de jeu dans `start_screen.gd` ni dans les menus.**
* **Valeurs réglables** (vitesse, seuils, durées) en `@export` ou en constantes nommées en haut du fichier.

### Entrées des manettes

Le gameplay gagne à ne pas mentionner `ArduinoManager`, de broche ou de trame `cle:valeur`. L'idée est une couche unique, l'autoload `ControllerInput` (à créer), qui traduit les signaux bruts en intentions de jeu (`piezo_hit(force)`, `joystick_moved(vecteur)`, `encoder_turned(delta)`, `button_pressed`) et fournit un clavier de remplacement pour jouer sans manette. Seul ce fichier connaît le matériel, ce qui permet à chacun de coder et tester sans carte. En attendant qu'elle existe, demander avant de brancher un capteur directement dans une scène. Le gyroscope est abandonné.

### Son

Le format n'est pas décidé (events FMOD via `FmodManager`, ou fichiers audio lus par Godot). En attendant, le gameplay peut émettre un signal dédié (`player_jumped`, `trap_triggered`...) plutôt que jouer un son, pour brancher le vrai son au même endroit plus tard. À mettre à jour une fois le format choisi.

## Style de code (suggestions)

* `snake_case` pour fichiers, variables et fonctions ; `PascalCase` pour classes et scènes. Code en anglais.
* Pas d'accents dans les identifiants, noms de fichiers et chemins `res://`. Les commentaires peuvent être en français avec accents.
* Casse exacte des chemins (`res://Scenes/Player.tscn`) : Windows l'ignore, Linux et la CI la vérifient.
* Variables et retours typés (`var vitesse: float = 5.0`, `func tirer() -> void:`).
* Fonctions courtes, pas de code mort, commentaires sur le **pourquoi**, pas de `print()` de debug dans ce qui est commité.

## Avant de dire "c'est fini"

1. Lancer le jeu (F5) : la fonctionnalité marche et la console est sans erreur rouge.
2. Relire son diff : pas de fichier inattendu.
3. Un commit par changement logique, préfixé comme l'équipe : `[ADD]`, `[UPDATE]`, `[FIX]`, `[REFACTOR]`, `[CHORE]`. Ajouter un asset ou une dépendance : le dire à l'équipe et le mentionner dans le commit.
4. Se mettre à jour souvent : `git pull --rebase origin dev`, et fusionner vers `dev` par petits morceaux plutôt qu'une grosse fusion vendredi.

## En cas de doute

Poser la question, ou choisir la solution la plus simple. Un code court et plat vaut mieux qu'une architecture ambitieuse que personne ne relira.

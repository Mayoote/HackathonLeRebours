# Escape the Temple (nom temporaire)

Projet de l'équipe 9 pour le hackathon Le Rebours (19 au 23 octobre 2026, rendu vendredi 23/10 à 10h).

Jeu d'évasion asymétrique à 2 joueurs sur le même écran, joué avec des manettes imprimées en 3D et pilotées par Arduino.
* **Joueur A (l'évadé)** : joystick 8 directions et bouton de saut. Il traverse les niveaux.
* **Joueur B (le saboteur)** : pas d'avatar, il voit toute la map et déclenche les pièges avec piezo, joystick et encodeur. Un piège n'est activable que quand A est à proximité.
* **Niveaux** : prairie (prise en main) et grotte (principal), salle des trésors et niveau final.

Le gyroscope est abandonné. L'état du projet et les règles du jeu sont tenus à jour dans les notes de l'équipe, pas ici.

## Versions imposées
| Outil | Version | Remarque |
|---|---|---|
| **Godot** | **4.7.2** standard (pas .NET) | rendu Forward Plus, GDScript uniquement |
| **FMOD GDExtension** | **6.1.0** (`addons/fmod/`, moteur FMOD 2.03.06) | déjà dans le dépôt |
| **FMOD Studio** (pour reconstruire une banque) | **2.03.x, jamais 2.04** | une banque 2.04 est refusée |
| **GdSerial** | **0.3.0** (`addons/gdserial/`) | déjà dans le dépôt |
| **Scene Package Exporter** | **0.1.1** (`addons/scene_exporter/`) | pour s'échanger des scènes sans Git |
| **Arduino** | UNO R3 | sketch dans `Arduino Code/` |

Cible de build : Windows. Un développeur est sur Linux : respecter la casse exacte des chemins (`res://Scenes/Player.tscn`).

## Démarrer
1. Cloner le dépôt et ouvrir `project.godot` dans Godot 4.7.2. Si des erreurs rouges `Nonexistent function ... in base 'FmodServer'` apparaissent au premier import, fermer et rouvrir le projet.
2. F5 lance `Scenes/Start.tscn` (écran de démarrage), qui mène à la scène de jeu.
3. Sans manette ni carte, le jeu doit rester jouable au clavier (voir la section suivante).

## Organisation du dépôt
| Dossier | Contenu |
|---|---|
| `Scenes/` | scènes du jeu : `Start`, `GameScene` (niveau en cours de construction), `Player`, `LevelAssets/` (sol, murs). `Game.tscn` est un reste du test de connexion Arduino. |
| `Scripts/` | scripts GDScript : joueur (`Player/`), série Arduino (`arduino_manager.gd`), écran de démarrage |
| `Meshes/` | assets 3D tiers (Quaternius, Isa Lousberg) |
| `FMOD Banks/` | banques sonores, remplacées par la personne du son |
| `Arduino Code/` | sketches pour la carte |
| `docs/` | protocole série, manette à encodeur |
| `tests/` | simulateur d'Arduino et tests headless |
| `addons/` | plugins tiers (FMOD, GdSerial, Scene Package Exporter) |

Les règles de contribution et les suggestions de répartition du travail sont dans `AGENTS.md`.

## Les manettes : ce que le script série sait faire
Autoload `ArduinoManager` (`Scripts/arduino_manager.gd`). Signaux : `arduino_connected`, `arduino_disconnected`, `pairing_success(port)`, `pairing_failed`, `button_changed(bool)`, `sensor_changed(int 0..1023)`, `encoder_changed(position, delta)`, `message_received(cle, valeur)` pour toute trame `cle:valeur` (un nouveau capteur : l'Arduino écrit `moncapteur:123`, Godot écoute `message_received`). Commandes : `send_led(bool)`, `send_blink(n)`, `send_ping()`.
* Forcer un port : variable d'environnement `ARDUINO_PORT=COM7` (Windows) ou `ARDUINO_PORT=/dev/ttyACM0` (Linux), définie dans le terminal qui lance Godot.
* Détail de l'appairage : `ARDUINO_DEBUG=1`.
* Protocole complet (115200 bauds, `DISCOVER` puis `GDSERIAL_ACK`, trames) : `docs/PROTOCOLE-ARDUINO-GODOT.md`.
* Fermer le moniteur série de l'IDE Arduino et débrancher les téléphones en USB (ils apparaissent comme des ports série).
* `Scripts/serial_tcp_simu.gd` est requis par le script série même sans simulateur : ne pas le supprimer.

Le gameplay ne parle pas directement à `ArduinoManager` : il passera par une couche d'entrée unique (`ControllerInput`, en cours de création) qui traduit les capteurs en intentions de jeu et fournit un clavier de remplacement.

## Tester sans carte
```
python3 tests/simulateur_arduino.py --tcp 5555 --profil base
```
puis, depuis le dossier du projet :
```
ARDUINO_PORT=tcp://127.0.0.1:5555 godot --headless --path . res://tests/test_arduino_headless.tscn
```
Attendu : `CONNECTE`, des `sensor_changed`, `button_changed`, puis `[TEST] BILAN apparie=true`. Windows : `py tests\simulateur_arduino.py --tcp 5555` puis `set ARDUINO_PORT=tcp://127.0.0.1:5555` (seul le mode TCP existe sous Windows).

## Échanger une scène sans Git (plugin Scene Package Exporter)
1. **Exporter** : dans le dock Système de fichiers, clic droit sur la scène `.tscn` puis "Exporter un paquet de scène...". On obtient un `.zip` à envoyer à un coéquipier.
2. **Importer** : menu Projet, Outils, "Importer un paquet de scène...". La fenêtre liste chaque fichier ("Sera ajouté", "OK" ou "Sera écrasé") : la lire avant de valider. Une version écrasée est copiée dans `scene_exporter_backups/<date>/`.
3. Enregistrer (Ctrl+S) et vérifier que la scène s'ouvre.

Ne pas recompresser le `.zip` à la main. Les banques FMOD ne voyagent pas dans le paquet.

## Manette à encodeur rotatif
Le script série lit les trames `enc:<position>` et émet `encoder_changed`. Explications : `docs/MANETTE-ENCODEUR.md`.

## Un problème ?
Symptômes et gestes (quarantaine Mac, erreurs FMOD, Arduino introuvable, crash du plugin FMOD après reconstruction de banque) : [`Godot_Blocks/docs/DEPANNAGE.md`](https://github.com/liaroc/Godot_Blocks/blob/hackathon-oct-2026/docs/DEPANNAGE.md).

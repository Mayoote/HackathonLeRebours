# Escape the Temple (nom temporaire)

Projet de l'équipe 9 pour le hackathon Le Rebours (19 au 23 octobre 2026, rendu vendredi 23/10 à 10h).

Jeu d'évasion asymétrique à 2 joueurs sur le même écran, joué avec des manettes imprimées en 3D et pilotées par Arduino.
* **Joueur A (l'évadé)** : joystick 8 directions et bouton de saut. Il traverse les niveaux.
* **Joueur B (le saboteur)** : pas d'avatar, il voit toute la map et déclenche les pièges avec piezo, joystick et encodeur.
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
| `Scenes/` | scènes du jeu : `Start`, `GameScene` (prairie), `Levels/` (grotte, temple, sortie), `Traps/`, `Player`, `LevelAssets/` (sol, murs). `Game.tscn` est un reste du test de connexion Arduino. |
| `Scripts/` | scripts GDScript : joueur (`Player/`), pièges (`Traps/`), manette (`manette.gd`), appairage série (`arduino_manager.gd`), chrono et niveaux (`partie.gd`), écran de démarrage |
| `Meshes/` | assets 3D tiers (Quaternius, Isa Lousberg) |
| `FMOD Banks/` | banques sonores, remplacées par la personne du son |
| `Arduino Code/` | sketch de test LED/bouton (`GODOTSERIAL`). Le sketch de la manette finale n'y est pas encore (voir la section suivante) |
| `docs/` | protocole série, manette à encodeur |
| `tests/` | simulateur d'Arduino et tests headless |
| `addons/` | plugins tiers (FMOD, GdSerial, Scene Package Exporter) |

Les règles de contribution et les suggestions de répartition du travail sont dans `AGENTS.md`.

## Les manettes : deux scripts série
Deux autoloads parlent à la carte, et il ne faut pas les confondre.

**`Manette` (`Scripts/manette.gd`) : celui du gameplay.** Il lit la manette finale et alimente le joueur (`Player/Character.gd`) et le piégeur (`trapper.gd`).
* Il lit des lignes de champs `Cle:valeur` séparés par des tabulations, avec toutes ces clés : `JoyX`, `JoyY`, `JoyBtn` (joystick 1, le joueur), `Joy2X`, `Joy2Y`, `Joy2Btn` (joystick 2, le piégeur), `EncPos`, `EncRPM`, `EncBtn` (encodeur), `PiezoA` (piézo). Une ligne incomplète est ignorée.
* Signaux : `piezo_hit(force)`, `joy_btn_pressed`, `joy2_btn_pressed`, `enc_btn_pressed`, `enc_tourne(delta)`. Valeurs lues directement : `joy`, `joy2` (de -1 à 1, avec zone morte), `enc_pos`, `enc_rpm`.
* **Le port série est écrit en dur : `PORT_SERIE := "COM5"`** en haut du script. Il change sur chaque ordinateur : le modifier à la main avant de lancer (par exemple `/dev/ttyACM0` sous Linux). Ce script ne lit pas `ARDUINO_PORT` et ne cherche pas la carte tout seul.
* Il n'y a ni reconnexion ni message en jeu si la manette est débranchée : seul un `push_error` s'affiche au lancement.
* **Le sketch Arduino qui envoie ce format n'est pas dans ce dépôt.** `Arduino Code/GODOTSERIAL/GODOTSERIAL.ino` est l'ancien test (LED, bouton, `DISCOVER`) et ne l'envoie pas. Le sketch de la manette est un livrable du rendu : le récupérer auprès de la personne qui gère l'Arduino et l'ajouter ici avec le schéma de câblage.

**`ArduinoManager` (`Scripts/arduino_manager.gd`) : l'appairage et le protocole de test.** Il n'est utilisé que par l'écran de démarrage (le voyant « Manette connectée ») et par `Game.tscn`. Signaux : `arduino_connected`, `arduino_disconnected`, `pairing_success(port)`, `pairing_failed`, `button_changed(bool)`, `sensor_changed(int 0..1023)`, `encoder_changed(position, delta)`, `message_received(cle, valeur)` pour toute trame `cle:valeur`. Commandes : `send_led(bool)`, `send_blink(n)`, `send_ping()`.
* Forcer un port : variable d'environnement `ARDUINO_PORT=COM7` (Windows) ou `ARDUINO_PORT=/dev/ttyACM0` (Linux), définie dans le terminal qui lance Godot. Cela ne concerne que `ArduinoManager`, pas `Manette`.
* Détail de l'appairage : `ARDUINO_DEBUG=1`.
* Protocole complet (115200 bauds, `DISCOVER` puis `GDSERIAL_ACK`, trames) : `docs/PROTOCOLE-ARDUINO-GODOT.md`.
* Fermer le moniteur série de l'IDE Arduino et débrancher les téléphones en USB (ils apparaissent comme des ports série).
* `Scripts/serial_tcp_simu.gd` est requis par le script série même sans simulateur : ne pas le supprimer.

Sans manette, le clavier remplace les capteurs (voir les actions de `project.godot` et l'en-tête de `trapper.gd`).
###
##### Tester sans carte
###```
###python3 tests/simulateur_arduino.py --tcp 5555 --profil base
###```
###puis, depuis le dossier du projet :
###```
###ARDUINO_PORT=tcp://127.0.0.1:5555 godot --headless --path . res://tests/test_arduino_headless.tscn
###```
###Attendu : `CONNECTE`, des `sensor_changed`, `button_changed`, puis `[TEST] BILAN apparie=true`. Windows : `py tests\simulateur_arduino.py --tcp 5555` puis `set ARDUINO_PORT=tcp://127.0.0.1:5555` (seul le mode TCP existe sous Windows).
###
###

## Échanger une scène sans Git (plugin Scene Package Exporter)
1. **Exporter** : dans le dock Système de fichiers, clic droit sur la scène `.tscn` puis "Exporter un paquet de scène...". On obtient un `.zip` à envoyer à un coéquipier.
2. **Importer** : menu Projet, Outils, "Importer un paquet de scène...". La fenêtre liste chaque fichier ("Sera ajouté", "OK" ou "Sera écrasé") : la lire avant de valider. Une version écrasée est copiée dans `scene_exporter_backups/<date>/`.
3. Enregistrer (Ctrl+S) et vérifier que la scène s'ouvre.

Ne pas recompresser le `.zip` à la main. Les banques FMOD ne voyagent pas dans le paquet.

## Manette à encodeur rotatif
Le script série lit les trames `enc:<position>` et émet `encoder_changed`. Explications : `docs/MANETTE-ENCODEUR.md`.

## Mode développeur
Le menu des niveaux (Tab, pour aller directement à un niveau avec un chrono neuf) est réservé aux tests. **F2** active ou désactive le mode développeur, avec un message en haut de l'écran. Sans ce mode, Tab ne fait rien. Code : `Scripts/level_menu.gd` (`TOUCHE_DEV`).

## Options et fin de partie
* **Volume** : bouton Options sur l'écran de démarrage, curseurs Musique et Effets (Effets règle aussi le bip des clés). 100 % garde le mixage du `default_bus_layout.tres`. Les réglages sont enregistrés dans `user://reglages.cfg` en quittant les options et rechargés par `Sfx` au lancement.
* **Écran de fin** : sous le titre, un résumé de la partie (pièges déclenchés par le piégeur, chutes du joueur, niveau atteint). Les compteurs sont dans `game_manager.gd` et survivent au changement de niveau. Le piégeur passe par `fire()` dans `trapper.gd`, qui émet `trap_fired` seulement si le piège part vraiment. Le vent, la grille et le rocher déplacé au joystick ne sont pas comptés.

## Reste à faire (état du 23/10)
* Récupérer le sketch Arduino de la manette et le schéma de câblage, les ajouter dans `Arduino Code/`.
* Salle des trésors : trouver un usage de l'encodeur (aujourd'hui sans effet à ce niveau).
* Rendre le lint bloquant dans la CI et renommer les 5 noms signalés.

Décisions assumées : pièges activables sans condition de proximité, vue isométrique 3D, chrono global de 300 s qui ne change pas.

## Un problème ?
Symptômes et gestes (quarantaine Mac, erreurs FMOD, Arduino introuvable, crash du plugin FMOD après reconstruction de banque) : [`Godot_Blocks/docs/DEPANNAGE.md`](https://github.com/liaroc/Godot_Blocks/blob/hackathon-oct-2026/docs/DEPANNAGE.md).

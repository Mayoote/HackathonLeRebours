# Test de connexion Arduino ↔ Godot (hackathon Le Rebours, 19–23 octobre 2026)

**Ce n'est pas le jeu de départ.** C'est un **mini-projet de test** à ouvrir en cinq minutes, avant le vrai projet de base ([`Godot_Blocks`](https://github.com/liaroc/Godot_Blocks), branche `hackathon-oct-2026`), pour vérifier que :
1. Godot 4.7.2 s'ouvre avec les deux plugins (FMOD, GdSerial) sur ta machine ;
2. ta carte Arduino est reconnue (pastille verte) et que le bouton et le capteur remontent dans Godot ;
3. le son FMOD sort.

Si ces trois points marchent ici, ils marcheront dans le projet de base : les deux projets utilisent **exactement le même script série** (`Scripts/arduino_manager.gd`) et les mêmes plugins.

## Versions imposées
| Outil | Version | Remarque |
|---|---|---|
| **Godot** | **4.7.2** standard (pas .NET) | `config/features` = 4.7 |
| **FMOD GDExtension** | **6.1.0** (`addons/fmod/`, moteur FMOD 2.03.06) | déjà dans le dépôt |
| **FMOD Studio** (si tu reconstruis une banque) | **2.03.x, jamais 2.04** | une banque 2.04 est refusée |
| **GdSerial** | **0.3.0** (`addons/gdserial/`, plugin Rust) | déjà dans le dépôt |
| **Scene Package Exporter** | **0.1.1** (`addons/scene_exporter/`, GDScript) | déjà dans le dépôt, pour s'échanger des scènes (voir plus bas) |

## Démarrer
1. Cloner (ou télécharger le zip). **Sur Mac**, si une alerte « non ouvert » apparaît ou si Godot se fige : lire `INSTALLATION_PLUGINS_MACOS.md` (cliquer **Terminé**, jamais Corbeille, puis `xattr -cr <dossier du projet>`). Avec `git clone`, pas de problème.
2. Ouvrir `project.godot` dans Godot 4.7.2. Si des erreurs rouges `Nonexistent function … in base 'FmodServer'` apparaissent au premier import : fermer et rouvrir le projet, elles disparaissent.
3. Téléverser `Arduino Code/GODOTSERIAL/GODOTSERIAL.ino` sur la carte (Uno, Nano…). Il attend un capteur analogique sur **A0** et un bouton sur la broche indiquée en tête du sketch ; la LED 13 répond à `led:1`.
4. **Fermer le moniteur série** de l'IDE Arduino et **débrancher les téléphones** en USB (ils apparaissent comme des ports série).
5. F5 : écran Start, pastille rouge « Arduino Pas Connectée ». Brancher la carte → pastille **verte** en 2–3 s → bouton **Start**.
6. Dans la scène : **flèches** = le personnage marche et on entend des pas (`CharacterMovement` = « Walk ») ; **Shift** = il court et le son change (« Run ») ; immobile = silence (« Void ») ; **bouton physique** = le texte passe rouge/bleu ; **bouton à l'écran** = la LED 13 s'allume ; le **capteur A0** fait bouger la valeur affichée. Débrancher la carte → « Arduino Déconnectée » en moins de 2 s ; rebrancher → ré-appairage en 3–5 s.

Console attendue : `FMOD Sound System: Successfully initialized`, `FMOD Sound System: LOADING BANK …/Master.bank`, puis `[Pairing]   → CONNECTÉ sur /dev/cu.usbmodem…` (Mac) ou `COM3` (Windows).

## Échanger des scènes avec ton équipe (plugin Scene Package Exporter)
Le projet contient un troisième plugin, `addons/scene_exporter/` (version 0.1.1), déjà activé. Il sert à passer une scène d'un ordinateur à l'autre **sans Git** : la scène part avec tout ce dont elle a besoin (scripts, images, sons, sous-scènes, autoloads).
1. **Exporter** : dans le dock **Système de fichiers**, clic droit sur ta scène `.tscn` → **Exporter un paquet de scène...** (en anglais : Export Scene Package...). Tu obtiens un `.zip` à envoyer à ton coéquipier (Discord, clé USB, Drive).
2. **Importer** : chez le coéquipier, menu **Projet → Outils → Importer un paquet de scène...** (Import Scene Package...), choisir le `.zip`. Si le `.zip` est déjà dans le dossier du projet, un clic droit dessus dans le dock donne la même commande. Une fenêtre liste chaque fichier : **Sera ajouté**, **Statut : OK** (identique) ou **Sera écrasé**. Lis-la avant de valider : un fichier « écrasé » remplace ta version. Ta version n'est pas perdue : le plugin la copie d'abord dans `scene_exporter_backups/<date>/` (dossier visible dans le Finder ou l'Explorateur, pas dans Godot).
3. Juste après l'import : **Cmd+S / Ctrl+S**, puis vérifier que la scène s'ouvre.

À savoir :
- Tout le monde dans l'équipe doit partir **de ce même projet de base** et avoir le plugin dans la même version.
- N'ouvre pas le `.zip` pour le recompresser avec le Finder ou l'Explorateur : un zip refait à la main ne s'importe plus. Envoie le fichier tel quel.
- Les banques FMOD (`FMOD Banks/`) ne voyagent pas dans le paquet : la personne du son les dépose directement dans le projet de chacun.
- Si Godot affiche un dossier `addons/scene_exporter 2/` (copie en double par le Finder), supprime-le.

## Ce que le script série sait faire (identique à Godot_Blocks)
Autoload `ArduinoManager`. Signaux : `arduino_connected`, `arduino_disconnected`, `pairing_success(port)`, `pairing_failed`, `button_changed(bool)`, `sensor_changed(int 0..1023)`, `encoder_changed(position, delta)`, `message_received(clé, valeur)` pour **toute** trame `clé:valeur` (pratique pour ton propre capteur : fais écrire `moncapteur:123` par l'Arduino, écoute `message_received`). Commandes : `send_led(bool)`, `send_blink(n)`, `send_ping()`.
- Forcer un port : variable d'environnement `ARDUINO_PORT=COM7` (Windows) ou `ARDUINO_PORT=/dev/cu.usbmodem1101` (Mac), définie dans le terminal qui lance Godot.
- Voir le détail de l'appairage : `ARDUINO_DEBUG=1`.
- Protocole complet (115200 bauds, `DISCOVER` → `GDSERIAL_ACK`, trames) : `docs/PROTOCOLE-ARDUINO-GODOT.md`.

## Tester sans carte
```
python3 tests/simulateur_arduino.py --tcp 5555 --profil base
```
puis, depuis le dossier du projet (Mac) :
```
ARDUINO_PORT=tcp://127.0.0.1:5555 "/Applications/Godot 4.7.2.app/Contents/MacOS/Godot" --headless --path . res://tests/test_arduino_headless.tscn
```
Attendu : `CONNECTÉ`, des `sensor_changed`, `button_changed`, puis `[TEST] BILAN apparie=true`. Windows : `py tests\simulateur_arduino.py --tcp 5555` puis `set ARDUINO_PORT=tcp://127.0.0.1:5555` (seul le mode TCP existe sous Windows). `Scripts/serial_tcp_simu.gd` est **requis** par le script série même si tu n'utilises jamais le simulateur : ne pas le supprimer.

## Manette à encodeur rotatif
Le brouillon de sketch `GODOTSERIAL_encodeur.ino` a été retiré par Tom le 18/10 : `GODOTSERIAL.ino` est désormais le code le plus simple de la formation Arduino (le bouton de l'UI allume la LED, le bouton de la manette change la couleur du texte). Le script série sait toujours lire une trame `enc:<position>` et émet alors `encoder_changed` ; explications et ancien brouillon : `docs/MANETTE-ENCODEUR.md` et l'historique git (commit `a5d380a`).

## Si le son ne correspond pas
Les trois labels envoyés à FMOD (« Void » au repos, « Walk » en marche, « Run » avec Shift) sont des **propriétés exportées** du nœud `Sprite2D` de `Game.tscn` (groupe « Labels FMOD du paramètre CharacterMovement » dans l'inspecteur) : si la banque change ou si on préfère « Fly » pour la course, on les modifie là, sans toucher au code. La banque actuelle accepte les quatre labels Walk, Run, Fly, Void (vérifié par `tests/test_son_headless.tscn`).

La fenêtre de jeu s'ouvre en 1280 × 720 (`window_width_override` / `window_height_override` dans `project.godot`) et met à l'échelle la scène dessinée en 1920 × 1080 (`stretch/aspect = keep`) : plus de fenêtre plus grande que l'écran ni d'image coupée. Pour le plein écran, la touche n'est pas définie dans ce mini-projet.

## Un problème ?
Les symptômes et les gestes (quarantaine Mac, erreurs FMOD, Arduino introuvable, crash du plugin FMOD après reconstruction de banque) sont dans le dépôt du projet de base : [`Godot_Blocks/docs/DEPANNAGE.md`](https://github.com/liaroc/Godot_Blocks/blob/hackathon-oct-2026/docs/DEPANNAGE.md).

## État au 18/10/2026
Testé en headless sur Mac (import, scènes, appairage avec le simulateur, démarrage de l'événement FMOD et changement de label par `tests/test_son_headless.tscn`, logs dans `docs/logs/`). Retours de Mourdjen du 18/10 corrigés : fenêtre plus grande que l'écran (image coupée) et aucun son avec Shift (l'événement était lancé avant que l'émetteur soit prêt, et le label de course « Fly » n'était pas celui qui sonne). Le test dans l'éditeur fenêtré, à l'oreille et avec une vraie carte est fait par Tom. Historique : projet d'avril 2026 (`test-communication-arduino-for-students`), passé en Godot 4.7.2 et corrigé les 15–17/10/2026 (chemin de scène `res://Scenes/Game.tscn`, script série fusionné avec celui de Godot_Blocks, chargeur de banque FMOD avant l'émetteur et banque `strings` chargée).

# Protocole Arduino ↔ Godot (projet démo « test-communication-arduino-for-students »)

L'Arduino et Godot échangent des **lignes de texte** à **115200 bauds**, au format `clé:valeur`, terminées par un retour à la ligne. Godot cherche la carte tout seul en envoyant `DISCOVER` sur chaque port USB plausible ; la carte répond `GDSERIAL_ACK:...` et se met ensuite à envoyer ses capteurs toutes les 50 ms. Il n'y a pas de vrai « battement de cœur » échangé : Godot vérifie seulement, toutes les 2 secondes, que le port est encore ouvert.

Sources lues : `Scripts/arduino_manager.gd` (autoload `ArduinoManager`) et `GODOTSERIAL.ino` ; variante prof : `AdaptGodot.ino`. Ce document décrit le code d'origine, puis signale ce que la copie corrigée (`T4-arduino/work/`) ajoute.

## 1. Couche physique

| Paramètre | Valeur | Où |
|---|---|---|
| Vitesse | 115200 bauds | `BAUD_RATE` (.gd), `Serial.begin(115200)` (.ino) |
| Format | 8 bits, sans parité, 1 bit de stop (défaut de GdSerial et de l'Arduino) | — |
| Fin de ligne Godot → Arduino | `\n` (`writeline`) | l'Arduino lit avec `readStringUntil('\n')` puis `trim()` |
| Fin de ligne Arduino → Godot | `\r\n` (`Serial.println`) | Godot coupe sur `\n` puis `strip_edges()` enlève le `\r` |
| Délai de lecture GdSerial | 10 ms | `serial.set_timeout(10)` |
| Bibliothèque | GdSerial 0.3.0 (GDExtension Rust, Sujith Christopher) | `addons/gdserial` |

**Point important : ouvrir le port redémarre l'Arduino Uno** (le signal DTR déclenche un reset). C'est pour ça que Godot attend 0,5 s après l'ouverture avant d'envoyer `DISCOVER`, et que la carte repart « non appariée » à chaque connexion.

> Précisions de la revue (16/10) : (1) GdSerial 0.3.0 s'appuie sur `serialport` 4.7.2, dont le réglage par défaut active DTR à l'ouverture sur Mac, Linux **et** Windows (`dtr_on_open: Some(true)` dans `serialport-rs/src/lib.rs`) : le reset a donc lieu partout. (2) La durée de boot « 0,3–0,5 s » n'est pas sourcée : le bootloader Optiboot de l'Uno attend jusqu'à ~1 s, mais il rend la main dès qu'il reçoit un octet qui n'est pas du protocole de téléversement. Le premier `DISCOVER` peut donc être « mangé » par le bootloader : une réponse à la tentative 2 est normale sur une vraie carte, ce n'est pas une panne. (3) **Les cartes sans reset à l'ouverture** (Leonardo, Micro, Pro Micro, Uno R4 : USB natif) ne redémarrent pas : avec `GODOTSERIAL.ino`, qui reste `paired = true` et ignore ensuite `DISCOVER`, Godot ne se ré-apparie plus après un redémarrage du jeu tant que la carte n'est pas débranchée ou remise à zéro. Le brouillon `GODOTSERIAL_encodeur.ino` n'a pas ce défaut (il accepte `DISCOVER` à tout moment).

## 2. Recherche de la carte (pairing)

### Côté Godot (`start_pairing` puis `_scan_ports`)

1. `serial.list_ports()` renvoie tous les ports série connus du système.
2. **Filtre sur le nom** : seuls les ports dont le nom contient `usbmodem`, `usbserial`, `ttyACM`, `ttyUSB` ou `COM` sont essayés (`PORT_NAME_HINTS`). Le but est d'éviter d'ouvrir `tty.Bluetooth-Incoming-Port` ou `tty.debug-console` sur Mac, qui bloquaient le scan. Correspondance typique : Uno officiel sur Mac = `/dev/cu.usbmodem…`, clone CH340 sur Mac = `/dev/cu.usbserial-…` ou `/dev/cu.wchusbserial…`, Linux = `/dev/ttyACM0` / `/dev/ttyUSB0`, Windows = `COM3`, `COM7`…
3. Pour chaque port candidat, l'un après l'autre :
   - ouverture, vidage du tampon, **attente 0,5 s** (boot de l'Arduino) ;
   - jusqu'à **3 envois** de `DISCOVER\n`, avec 0,1 s d'attente après chacun ;
   - si la réponse lue contient `GDSERIAL_ACK`, le port est retenu : signaux `pairing_success(port)` puis `arduino_connected()` ;
   - sinon fermeture et port suivant.
4. Aucun port ne répond : signal `pairing_failed()`, nouvelle tentative **2 s** plus tard (`SCAN_RETRY_COOLDOWN`), indéfiniment.

Un port candidat qui ne répond pas coûte donc environ 0,8 s. Sur Mac, chaque appareil apparaît deux fois (`cu.` et `tty.`), donc 1,6 s par appareil.

### Côté Arduino

`setup()` boucle tant qu'il n'a pas reçu la ligne `DISCOVER`. Il répond alors `GDSERIAL_ACK:arduino_uno`, passe `paired = true` et allume la LED 13 (`GODOTSERIAL.ino` seulement ; `AdaptGodot.ino` n'allume rien). La partie après `GDSERIAL_ACK:` n'est pas lue par Godot ; elle peut servir à nommer la manette.

```
Godot                                   Arduino (vient de redémarrer)
  | ouvre le port --------------------->  reset DTR, boot (~0,3-0,5 s)
  | attend 0,5 s
  | DISCOVER\n ------------------------>
  |                                       Serial.println("GDSERIAL_ACK:arduino_uno")
  | <------------- GDSERIAL_ACK:arduino_uno\r\n
  | (apparié)                             (apparié, LED 13 allumée)
  | <------------- sensor:512\r\n          toutes les 50 ms
  | <------------- button:1\r\n            à chaque changement
```

## 3. Trames Arduino → Godot

| Trame | Quand | Envoyée par | Traitée par le `.gd` d'origine ? |
|---|---|---|---|
| `GDSERIAL_ACK:arduino_uno` | réponse à `DISCOVER` | les deux `.ino` | oui (pairing) |
| `sensor:<0..1023>` | toutes les 50 ms | `GODOTSERIAL.ino` (`analogRead(A0)`) | **non, ignorée** |
| `button:1` / `button:0` | à chaque changement d'état du bouton (pin 2, `INPUT_PULLUP`, 1 = appuyé) | les deux `.ino` | oui → `button_changed(bool)` |
| `pong:<t>` | réponse à `ping:<t>` | les deux `.ino` | oui → affiche la latence |
| `ack:led:<v>`, `ack:blink:<n>` | réponse à `led` / `blink` | `GODOTSERIAL.ino` | oui → affiche « Ack » |
| `ack:led1:<v>`, `ack:led2:…`, `ack:led3:…` | réponse à `led` | `AdaptGodot.ino` | oui → affiche « Ack » |
| `ultrason:<cm, 1 décimale>` | toutes les 50 ms | `AdaptGodot.ino` | **non, ignorée** |
| `potentiometre:<0..1023>` | toutes les 50 ms | `AdaptGodot.ino` | **non, ignorée** |

Le découpage côté Godot se fait sur le **premier** `:` seulement (`split(":", false, 1)`) : `ack:led:1` donne la clé `ack` et la valeur `led:1`. Une ligne sans `:` est ignorée.

Le bouton n'est **pas anti-rebondi** côté Arduino : un appui peut produire `button:1`, `button:0`, `button:1` en quelques millisecondes. L'échantillonnage toutes les 50 ms limite le phénomène sans le supprimer.

## 4. Commandes Godot → Arduino

| Fonction GDScript (`ArduinoManager.…`) | Ligne envoyée | Effet dans `GODOTSERIAL.ino` | Effet dans `AdaptGodot.ino` |
|---|---|---|---|
| `send_led(true/false)` | `led:1` / `led:0` | LED 13 allumée/éteinte, répond `ack:led:x` | allume la LED suivante (1, 2 puis 3) ; à la 3ᵉ, bloque 3 s puis éteint tout |
| `send_blink(n)` | `blink:<n>` | fait clignoter la LED n fois (**bloquant** : 200 ms par clignotement, aucune trame envoyée pendant ce temps) | rien |
| `send_ping()` | `ping:<ms>` | répond `pong:<ms>` | répond `pong:<ms>` |
| (pas de fonction) | `vibe:<x>` | rien | vibreur pin 10 |
| (pas de fonction) | `final:<x>` | rien | censé éteindre les LED |

Si Godot n'est pas apparié, `_send` affiche un avertissement et n'envoie rien.

## 5. « Heartbeat » et déconnexion

Il n'y a **pas de message de vie** échangé. Toutes les 2 secondes (`timerHeartBeatMax`), Godot appelle `serial.is_open()`. Dans GdSerial 0.3.0, cette fonction interroge réellement le port (nombre d'octets en attente) ; si le système répond par une erreur, comme quand on débranche le câble, le port est marqué fermé. Godot émet alors `arduino_disconnected()` et relance la recherche, qui rouvrira la carte quand elle sera rebranchée.

Conséquence : une carte **plantée mais toujours branchée** (boucle infinie, `delay` géant) n'est pas détectée. Le port reste ouvert, aucune donnée n'arrive, Godot se croit connecté.

## 6. Bugs et fragilités relevés dans le code d'origine

1. **Les trames capteur sont ignorées par Godot.** `sensor:`, `potentiometre:` et `ultrason:` tombent dans la branche `_:` de `_parse_message`. Un étudiant qui veut lire le potentiomètre doit modifier `arduino_manager.gd`. *Corrigé dans la copie* (signal `sensor_changed`, signal générique `message_received`).
2. Après un ré-appariement, `_buffer` n'est jamais vidé : un morceau de ligne de l'ancienne connexion peut se coller à la première nouvelle ligne. Et les trames arrivées dans la même lecture que l'ACK sont perdues. *Corrigé dans la copie.*
3. `game.gd` déclare `_on_arduino_ready()` (qui envoie un ping) mais ne la connecte à aucun signal : elle n'est jamais appelée. Non modifié.
4. `AdaptGodot.ino`, commande `vibe` : `digitalWrite(VIB_PIN, value ? HIGH : LOW)` teste si la **chaîne** est non vide, donc `vibe:0` allume aussi le vibreur. Il faudrait `value == "1"`. Non modifié (fichier d'entrée).
5. `AdaptGodot.ino`, commande `led` : le compteur `nbLed` n'est jamais remis à zéro ; à partir du 4ᵉ `led:`, plus rien ne se passe. La commande `final` éteint trois fois les mêmes LED sans clignotement. Non modifié.
6. `blink` est bloquant côté Arduino (2 s pour `blink:10`) : pendant ce temps, ni capteur ni bouton ne remontent.
7. Le scan envoie `DISCOVER` à **tout appareil USB série** dont le nom correspond au filtre. Constaté cette nuit : un téléphone Samsung branché en USB apparaît sur Mac comme `/dev/cu.usbmodemR5CX606MB9R2` et a reçu `DISCOVER` (sans effet, il ne répond pas). Sans gravité, mais le scan est ralenti d'environ 1,6 s par téléphone branché. `list_ports()` donne aussi le VID/PID USB (`USB - VID: 04E8, PID: 6860`) : un filtre sur les VID Arduino (2341 Arduino, 1A86 CH340, 0403 FTDI, 10C4 CP210x) serait plus fiable que le nom, mais je ne l'ai pas codé.

8. *(Ajout de la revue du 16/10)* `AdaptGodot.ino` : `pulseIn(ECHO_PIN, HIGH)` est appelé sans délai maximal, donc avec le délai par défaut d'**1 seconde**. Si le capteur à ultrasons est absent, débranché ou ne reçoit pas d'écho, chaque envoi bloque environ 1 s : les trames arrivent à 1 Hz au lieu de 20 Hz, et les commandes de Godot (ping, led) attendent jusqu'à 1 s. Correction possible : `pulseIn(ECHO_PIN, HIGH, 30000)` (30 ms, environ 5 m).
9. *(Ajout de la revue du 16/10)* GdSerial `read_string()` renvoie une chaîne **vide** si le morceau lu n'est pas de l'UTF-8 valide (parasites au démarrage, mauvaise vitesse) : tout le morceau est perdu, y compris un éventuel ACK ou un début de trame. Rare avec des trames ASCII ; sans gravité pour le pairing, qui fait 3 tentatives.

## 7. Ce que la copie corrigée ajoute (rétro-compatible)

Rien n'est retiré : `button_changed`, `send_led`, `send_blink`, `send_ping` et les signaux de connexion marchent comme avant. Détail ligne à ligne dans `T4-arduino/DIFF.md`.

- **Nouveaux signaux** : `sensor_changed(value: int)` pour `sensor:`, `encoder_changed(position: int, delta: int)` pour `enc:` (future manette de Tom), `message_received(key: String, value: String)` pour **toute** trame (permet de lire `potentiometre`, `ultrason` ou un capteur maison sans toucher au script).
- *(Précision de la revue du 16/10)* `sensor_changed` est émis à **chaque** trame `sensor:` reçue (20 fois par seconde), même si la valeur n'a pas changé ; `encoder_changed`, lui, n'est émis que si la position change. Un jeu qui ne doit réagir qu'aux changements compare avec la valeur précédente.
- **Variables lisibles à tout moment** : `ArduinoManager.sensor_value`, `encoder_position`, `button_pressed`.
- **Clés insensibles à la casse** : `ENC:3` et `enc:3` sont équivalents.
- **Port forcé** : variable d'environnement `ARDUINO_PORT` ou fichier `user://port_override.txt`. Quand il est défini, c'est le **seul** port essayé, même s'il n'apparaît pas dans `list_ports()` et même si son nom ne passe pas le filtre. Utile pour le simulateur, ou pour une carte au nom exotique sans modifier `PORT_NAME_HINTS`.
- **Mode simulateur** : si `ARDUINO_PORT` commence par `tcp://`, GdSerial est remplacé par `Scripts/serial_tcp_simu.gd`, qui parle au simulateur Python. Voir `SIMULATEUR.md`.
- **Traces de pairing** : `ARDUINO_DEBUG=1` réactive les messages `[Pairing] …` qui étaient commentés.

## 8. Protocole proposé pour l'encodeur

Voir `MANETTE-ENCODEUR.md`. En bref : nouvelle trame `enc:<position absolue>` envoyée seulement quand la position change, à côté de `button:` et (si on le garde) `sensor:`. Un ancien jeu qui ne connaît pas `enc` l'ignore sans erreur.

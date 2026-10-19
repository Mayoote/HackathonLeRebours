# Nouvelle manette de Tom (encodeur rotatif + bouton) : ce qu'il faut adapter

**Proposition : la manette envoie une nouvelle trame `enc:<position>` à chaque cran, garde `button:` tel quel, et continue d'envoyer `sensor:` en convertissant la position de l'encodeur en valeur 0–1023.** Ainsi, un jeu écrit pour l'ancien potentiomètre marche sans modification, et un jeu récent peut lire l'encodeur cran par cran. Côté Godot, la copie corrigée accepte déjà les deux. Le brouillon `.ino` est prêt mais **n'a jamais été téléversé** : il compile pour l'Uno, rien de plus.

Fichiers :
- `livrables/GODOTSERIAL_encodeur/GODOTSERIAL_encodeur.ino` : brouillon (compilé avec `arduino-cli 1.4.1`, carte `arduino:avr:uno` : 5770 octets, 17 % ; non testé sur carte).
- `work/Scripts/arduino_manager.gd` : version qui comprend `enc:` (déjà faite et testée avec le simulateur, profil `encodeur`).

## 1. Pourquoi une position absolue plutôt qu'un delta

L'Arduino envoie la position (`enc:5`, `enc:6`, `enc:5`…) et Godot calcule lui-même la différence avec la valeur précédente. Si une ligne se perd ou arrive coupée, la position suivante remet tout d'aplomb ; avec des deltas (`enc:+1`), chaque ligne perdue fausserait la position pour toujours. La position repart de 0 à chaque pairing, des deux côtés (l'Arduino redémarre à l'ouverture du port, et `arduino_manager.gd` remet `encoder_position` à 0).

## 2. Points à adapter côté `.ino` (par rapport à `GODOTSERIAL.ino`)

| # | Point | Ancien | Nouveau (brouillon) |
|---|---|---|---|
| 1 | Broches | `SENSOR_PIN = A0` (potentiomètre), `BUTTON_PIN = 2` | `ENC_CLK = 3`, `ENC_DT = 4`, `BUTTON_PIN = 2`. **À corriger selon le câblage réel de Tom.** |
| 2 | Pairing | boucle `while (!paired)` bloquante dans `setup()` | pairing traité dans `loop()` : l'encodeur est lu dès le démarrage et un `DISCOVER` tardif est toujours accepté |
| 3 | Lecture de l'encodeur | — | `readEncoder()` à chaque tour de `loop()` : un cran = front descendant sur CLK, le niveau de DT donne le sens. Pas d'interruption, pas de bibliothèque. |
| 4 | Nouvelle trame | — | `enc:<position>` envoyée **seulement quand la position change** |
| 5 | Trame capteur | `sensor:<analogRead(A0)>` | `sensor:<512 + position × 32>`, bornée à 0–1023 (32 crans pour parcourir toute la plage ; réglable avec `PAS_SENSOR`) |
| 6 | Bouton | changement d'état sans anti-rebond | même trame `button:1/0`, avec un anti-rebond simple : on ignore un changement à moins de 30 ms du précédent |
| 7 | ACK | `GDSERIAL_ACK:arduino_uno` | `GDSERIAL_ACK:manette_encodeur` (Godot ne lit que le préfixe ; le nom aide à savoir quelle manette est branchée) |
| 8 | Sens de rotation | — | `INVERSER_SENS = true` si la position diminue en tournant à droite |
| 9 | `blink` | bloquant | toujours bloquant, et pendant ce temps **les crans sont perdus** : garder de petites valeurs (commentaire dans le code) |

Deux variantes possibles selon ce que Tom a monté :
- **L'encodeur a son propre bouton poussoir (broche SW)** : le brancher sur `BUTTON_PIN`, ou ajouter un second bouton. Pour un second bouton, envoyer une autre clé (`button2:1/0`) ; elle remontera par le signal `message_received` sans rien changer d'autre.
- **Nombre de comptes par cran** (corrigé par la revue du 16/10) : le brouillon ne compte que les **fronts descendants** de CLK, donc un encodeur dont CLK change deux fois par cran (cycle complet par cran, cas courant du KY-040 20 crans) donne bien **1 par cran**. Deux écarts sont possibles : **+2 ou +3 par cran** = rebonds des contacts sur CLK (il n'y a aucun anti-rebond sur l'encodeur dans le brouillon : ajouter un condensateur de 10–100 nF entre CLK et GND, ou ignorer les fronts à moins de 1–2 ms, ou passer à un décodage par table d'états) ; **+1 tous les deux crans** = encodeur « demi-pas » où CLK ne change qu'une fois par cran (compter alors les deux fronts : retirer la condition `clk == LOW` dans `readEncoder()` ; le test de sens `DT != CLK` reste valable sur les deux fronts). À vérifier en tournant d'un seul cran pendant le test.

Si Tom tient à garder le potentiomètre **en plus** de l'encodeur : remettre `analogRead(A0)` dans la trame `sensor:` et ne pas utiliser la conversion.

## 3. Points à adapter côté `arduino_manager.gd`

Tout est fait dans `work/Scripts/arduino_manager.gd` ; voici la liste pour pouvoir le refaire à la main dans un autre projet.

| # | Point | Changement |
|---|---|---|
| 1 | Signal | ajouter `signal encoder_changed(position: int, delta: int)` |
| 2 | Variable | ajouter `var encoder_position: int = 0` |
| 3 | Remise à zéro | dans `start_pairing()`, `encoder_position = 0` (et `_buffer = ""`) |
| 4 | Lecture | dans `_parse_message`, une branche `"enc":` qui calcule `delta = nouvelle_position - encoder_position`, met à jour la variable et émet le signal si `delta != 0` |
| 5 | Capteur | une branche `"sensor":` qui émet `sensor_changed(value)` (elle manquait dans l'original : les trames `sensor:` étaient ignorées) |
| 6 | Casse | `var key := parts[0].to_lower()` pour accepter `ENC:` comme `enc:` |
| 7 | Générique | `message_received(key, value)` émis pour toute trame, pour les capteurs maison |

Le code de la branche, tel qu'il est dans la copie :

```gdscript
"enc":
    var new_position := value.to_int()
    var delta := new_position - encoder_position
    encoder_position = new_position
    if delta != 0:
        emit_signal("encoder_changed", encoder_position, delta)
```

## 4. Exemple d'utilisation dans un jeu

```gdscript
func _ready() -> void:
    ArduinoManager.encoder_changed.connect(_on_encoder)
    ArduinoManager.button_changed.connect(_on_button)

func _on_encoder(position: int, delta: int) -> void:
    $Curseur.rotation_degrees += delta * 15   # 15° par cran
    # ou, en absolu : $Curseur.rotation_degrees = position * 15

func _on_button(pressed: bool) -> void:
    if pressed:
        print("Tir !")
```

Pour un jeu écrit pour l'ancien potentiomètre, rien à changer : `sensor_changed(value)` ou `ArduinoManager.sensor_value` continuent de donner une valeur entre 0 et 1023.

## 5. Ce que ce brouillon ne garantit pas

- **Jamais téléversé ni testé sur une carte.** Le sens de rotation, le nombre de comptes par cran et les broches sont à vérifier avec la manette réelle (voir `CHECKLIST-TEST-VRAIE-CARTE.md`, partie B).
- La lecture par scrutation (sans interruption) suffit pour une rotation à la main ; un mouvement très rapide peut sauter des crans, surtout pendant un `blink`.
- Pas de vérification sur Windows.

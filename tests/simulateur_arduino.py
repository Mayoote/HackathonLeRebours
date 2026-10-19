#!/usr/bin/env python3
"""
Simulateur d'Arduino pour tester arduino_manager.gd (GdSerial) sans carte.

Il crée un pseudo-terminal (pty) qui se comporte comme GODOTSERIAL.ino :
  - avant le pairing : silence, attend "DISCOVER" et répond "GDSERIAL_ACK:arduino_uno" ;
  - après le pairing : envoie "sensor:<0..1023>" toutes les 50 ms,
    "button:1" / "button:0" à chaque changement (bouton simulé),
    et, avec --profil encodeur, "enc:<position>" à chaque cran ;
  - répond à "led:x" -> "ack:led:x", "blink:n" -> "ack:blink:n", "ping:t" -> "pong:t".

Usage :
  python3 simulateur_arduino.py                       # profil "base", tourne jusqu'à Ctrl+C
  python3 simulateur_arduino.py --duree 30            # s'arrête seul au bout de 30 s
  python3 simulateur_arduino.py --profil encodeur     # trames de la future manette de Tom
  python3 simulateur_arduino.py --profil prof         # trames de AdaptGodot.ino (ultrason, potentiometre)
  python3 simulateur_arduino.py --lien /tmp/tty.usbmodemSIM   # crée aussi un lien symbolique

Le chemin du port s'affiche au démarrage (ex. /dev/ttys012). Godot ne le verra PAS
dans GdSerial.list_ports() (macOS n'énumère que les ports IOKit) : il faut le donner
à arduino_manager.gd via la variable d'environnement ARDUINO_PORT.

IMPORTANT (vérifié le 15/10/2026, macOS 26, GdSerial 0.3.0) : GdSerial NE SAIT PAS ouvrir un pty
sur macOS ("Failed to open port /dev/ttysXXX: Not a typewriter", à toutes les vitesses). Le mode
pty sert donc à tester avec d'autres outils (screen, pyserial, Linux). Pour tester Godot sur Mac,
utiliser le mode TCP :
  python3 simulateur_arduino.py --tcp 5555
  ARDUINO_PORT=tcp://127.0.0.1:5555 "<Godot>" --headless --path <projet> ...
arduino_manager.gd remplace alors GdSerial par Scripts/serial_tcp_simu.gd (même API, via TCP).

Windows : seul le mode --tcp fonctionne (pas de pty) ; lancer avec  py tests\\simulateur_arduino.py --tcp 5555 --profil prof
puis, avant d'ouvrir Godot depuis le même terminal :  set ARDUINO_PORT=tcp://127.0.0.1:5555

Le profil « prof » est plus permissif que le vrai AdaptGodot.ino : il répond à DISCOVER à tout moment et traite
« blink », ce que le sketch du dépôt ne fait pas (voir docs/NOTES-POUR-TOM.md).

Uniquement la bibliothèque standard Python. Mode pty : macOS / Linux ; mode --tcp : macOS / Linux / Windows.
"""
import argparse
import math
import os
import select
import signal
import socket
import sys
import time
try:
    import pty
    import tty
except ImportError:  # Windows : pas de pseudo-terminal, seul le mode --tcp est disponible
    pty = None
    tty = None

ACK = "GDSERIAL_ACK:arduino_uno"
SEND_INTERVAL = 0.050  # 50 ms, comme SEND_INTERVAL dans GODOTSERIAL.ino


def log(msg):
    print(time.strftime("%H:%M:%S") + " [SIM] " + msg, flush=True)


def main():
    ap = argparse.ArgumentParser(description="Simulateur Arduino (pty) pour GdSerial / arduino_manager.gd")
    ap.add_argument("--profil", choices=["base", "encodeur", "prof"], default="base",
                    help="base = GODOTSERIAL.ino ; encodeur = manette de Tom (enc + bouton) ; prof = AdaptGodot.ino")
    ap.add_argument("--duree", type=float, default=0, help="arrêt automatique après N secondes (0 = jamais)")
    ap.add_argument("--lien", default="", help="crée un lien symbolique vers le pty (ex. /tmp/tty.usbmodemSIM)")
    ap.add_argument("--fichier-port", default="", help="écrit le chemin du pty dans ce fichier (pratique pour les scripts)")
    ap.add_argument("--bouton-periode", type=float, default=2.0, help="le bouton simulé change d'état toutes les N s")
    ap.add_argument("--tcp", type=int, default=0,
                    help="au lieu d'un pty, écoute sur 127.0.0.1:<port> (obligatoire pour Godot sur macOS et sur Windows)")
    ap.add_argument("--muet", action="store_true", help="n'affiche pas chaque trame envoyée (seulement les reçues)")
    args = ap.parse_args()

    server = None
    conn = {"c": None}  # client TCP courant
    master = slave = None
    if args.tcp:
        server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        server.bind(("127.0.0.1", args.tcp))  # localhost uniquement
        server.listen(1)
        port = "tcp://127.0.0.1:" + str(args.tcp)
        args.lien = ""
    else:
        master, slave = pty.openpty()
        port = os.ttyname(slave)
        # Mode brut côté esclave : pas d'écho, pas de transformation \n -> \r\n.
        # (GdSerial reconfigure de toute façon le port en brut à l'ouverture.)
        tty.setraw(slave)
        # On garde 'slave' ouvert dans ce processus : sinon, à chaque fermeture du port
        # par Godot, le maître reçoit un "hang-up" et les lectures échouent (EIO).

    if args.lien:
        if os.path.lexists(args.lien):
            # Prudence : on n'efface jamais un fichier existant. Supprimez-le vous-même.
            log("le chemin " + args.lien + " existe déjà : lien NON créé")
            args.lien = ""
        else:
            try:
                os.symlink(port, args.lien)
                log("lien " + args.lien + " -> " + port)
            except OSError as e:
                log("impossible de créer le lien " + args.lien + " : " + str(e))
                args.lien = ""
    if args.fichier_port:
        with open(args.fichier_port, "w") as f:
            f.write(port + "\n")

    log("profil=" + args.profil + "  PORT=" + port)
    log("Dans un autre terminal :  ARDUINO_PORT=" + port + " <godot> --headless --path <projet>")

    stop = {"v": False}
    signal.signal(signal.SIGTERM, lambda *_: stop.__setitem__("v", True))
    signal.signal(signal.SIGINT, lambda *_: stop.__setitem__("v", True))

    paired = False
    rx = b""
    t0 = time.time()
    last_send = 0.0
    last_btn_toggle = time.time()
    button = False
    enc_pos = 0
    last_enc = time.time()
    sent = 0

    def send(line, quiet=False):
        nonlocal sent
        data = (line + "\r\n").encode()  # Serial.println() envoie \r\n
        if args.tcp:
            if conn["c"] is None:
                return
            try:
                conn["c"].sendall(data)
            except OSError:
                return
        else:
            os.write(master, data)
        sent += 1
        if not (quiet or args.muet):
            log("-> " + line)

    while not stop["v"]:
        now = time.time()
        if args.duree and now - t0 > args.duree:
            break

        if args.tcp:
            watch = [server] if conn["c"] is None else [conn["c"]]
        else:
            watch = [master]
        r, _, _ = select.select(watch, [], [], 0.01)
        if r and args.tcp and conn["c"] is None:
            c, addr = server.accept()
            conn["c"] = c
            # Ouvrir le port = reset de l'Arduino (DTR) : on repart non apparié.
            paired, rx = False, b""
            enc_pos = 0
            log("client TCP connecté " + str(addr) + " (= ouverture du port, reset)")
            continue
        if r:
            try:
                data = conn["c"].recv(1024) if args.tcp else os.read(master, 1024)
            except OSError:
                data = b""
            if args.tcp and not data:
                log("client TCP déconnecté (= fermeture du port)")
                conn["c"].close()
                conn["c"] = None
                paired = False
                continue
            rx += data
            while b"\n" in rx:
                raw, rx = rx.split(b"\n", 1)
                cmd = raw.decode(errors="replace").strip()
                if not cmd:
                    continue
                log("<- " + cmd)
                if cmd == "DISCOVER":
                    # Le vrai .ino ne répond qu'une fois (il redémarre à chaque ouverture du port
                    # grâce au reset DTR). Le simulateur, lui, ne redémarre pas : il répond à
                    # chaque DISCOVER pour que Godot puisse se re-pairer après une fermeture.
                    send(ACK)
                    paired = True
                elif paired and ":" in cmd:
                    key, value = cmd.split(":", 1)
                    if key == "led":
                        send("ack:led:" + value)
                    elif key == "blink":
                        send("ack:blink:" + value)
                    elif key == "ping":
                        send("pong:" + value)

        if not paired:
            continue

        # Bouton simulé (INPUT_PULLUP côté Arduino : on n'envoie que les changements)
        if now - last_btn_toggle >= args.bouton_periode:
            last_btn_toggle = now
            button = not button
            send("button:" + ("1" if button else "0"))

        if args.profil == "encodeur" and now - last_enc >= 0.25:
            # un cran toutes les 250 ms : 8 crans dans un sens, 8 dans l'autre
            last_enc = now
            step = 1 if int((now - t0) / 2.0) % 2 == 0 else -1
            enc_pos += step
            send("enc:" + str(enc_pos))

        if now - last_send >= SEND_INTERVAL:
            last_send = now
            phase = (now - t0) * 0.5
            value = int(511.5 + 511.5 * math.sin(phase))
            if args.profil == "prof":
                send("ultrason:" + format(20 + 10 * math.sin(phase), ".1f"), quiet=True)
                send("potentiometre:" + str(value), quiet=True)
            else:
                send("sensor:" + str(value), quiet=True)

    log("arrêt. trames envoyées : " + str(sent))
    if args.lien and os.path.islink(args.lien):
        os.unlink(args.lien)  # uniquement le lien créé par ce script, au démarrage
    if args.tcp:
        if conn["c"] is not None:
            conn["c"].close()
        server.close()
    else:
        os.close(master)
        os.close(slave)


if __name__ == "__main__":
    sys.exit(main())

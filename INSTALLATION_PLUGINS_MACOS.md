# Installation des plugins GDExtension sur macOS

macOS bloque par défaut les librairies GDExtension car elles ne sont pas signées par Apple. Voici comment les autoriser.

## En 3 étapes (ajout du 17/10/2026)

**À qui ça arrive :** tu es sur Mac, tu as récupéré le projet ou un plugin par ton navigateur, **AirDrop**, une pièce jointe Mail/Messages ou **Discord**, et en ouvrant le projet : une fenêtre dit **« Élément "libxxx.dylib" non ouvert »**, ou Godot reste **figé** puis « a quitté de manière imprévue ». macOS marque tout ce qui vient d'Internet (« quarantaine ») ; quand tu décompresses le zip en double-cliquant, tous les fichiers héritent de la marque. Ton projet n'est pas cassé. **Ce qui ne pose pas la quarantaine :** `git clone`, `curl`, `unzip` dans le Terminal.

1. **Dans la fenêtre d'alerte, clique sur « Terminé ».** ⚠️ **Jamais « Placer dans la corbeille »** : macOS supprimerait le plugin. (Si c'est fait : Corbeille → clic droit → « Remettre ».) Puis quitte Godot (s'il est figé :  → Forcer à quitter).
2. **Ouvre Terminal** (Cmd + Espace, tape `Terminal`), tape `xattr -cr ` **avec l'espace à la fin**, puis **glisse le dossier du projet** (celui qui contient `project.godot`) depuis le Finder dans la fenêtre : le chemin s'écrit tout seul. Entrée. Aucun message = c'est bon. Si macOS demande l'accès au dossier Téléchargements/Documents : **Autoriser**, puis relance la commande.
3. **Rouvre le projet** dans Godot 4.7.2.

Ça bloque encore ? Réglages Système → Confidentialité et sécurité, en bas : **« Ouvrir quand même »** / **« Autoriser quand même »**, puis rouvrir. Toujours bloqué : re-décompresse le zip d'origine, refais l'étape 2 **avant** d'ouvrir Godot. Sinon, appelle un encadrant.

**Astuce :** fais l'étape 2 dès que tu télécharges un projet ou un plugin, **avant** de l'ouvrir. Et chaque fois que tu récupères le projet d'un coéquipier par Discord, AirDrop ou mail : nouvelle copie = nouvelle quarantaine. Si vous passez par `git clone`, le problème n'existe pas.

---

## Détail technique (pourquoi, et méthode fichier par fichier)

## Pourquoi ces alertes apparaissent-elles ?

Les alertes de sécurité macOS (Gatekeeper) sont **normales et attendues**. Elles ne signifient pas que les fichiers sont dangereux. Ce problème touche **tous les plugins GDExtension** distribués en dehors du Mac App Store ([godot-proposals #13657](https://github.com/godotengine/godot-proposals/issues/13657)).

### FMOD GDExtension

**Librairies FMOD SDK** (`libfmod.dylib`, `libfmodstudio.dylib`) :
- Signées officiellement par **Firelight Technologies** (Apple Developer ID : `FNXNE97GV7`)
- Firelight Technologies est l'éditeur de FMOD, un middleware audio utilisé par des jeux AAA (World of Warcraft, Crysis, Bioshock)
- Ces fichiers sont authentiques et vérifiables via `codesign -dvvv`

**Wrapper GDExtension** (`libGodotFmod.macos.*`) :
- Compilé depuis le code source ouvert via **GitHub Actions CI** ([utopia-rise/fmod-gdextension](https://github.com/utopia-rise/fmod-gdextension), 800+ étoiles, licence MIT)
- Signé en mode **adhoc** (sans Apple Developer ID) — c'est ce qui déclenche les alertes
- Les mainteneurs n'ont pas de certificat Apple organisationnel ([issue #109](https://github.com/utopia-rise/fmod-gdextension/issues/109))

### GdSerial (communication série Arduino)

**Librairie** (`libgdserial.dylib`) :
- Plugin Rust pour la communication série avec Arduino et capteurs ([gdserial](https://github.com/AceMouse/gdserial))
- Signé en mode **adhoc** (sans Apple Developer ID) — même situation que FMOD
- 2 fichiers macOS concernés : `bin/macos-arm64/libgdserial.dylib` et `bin/macos-x86_64/libgdserial.dylib`

## Méthode rapide (Terminal)

Ouvrez un terminal dans le dossier du projet et exécutez :

```bash
# Tout débloquer d'un coup (FMOD + GdSerial + tout futur plugin)
xattr -dr com.apple.quarantine addons/
```

Ou plugin par plugin :

```bash
# FMOD uniquement
xattr -dr com.apple.quarantine addons/fmod/libs/macos/

# GdSerial uniquement
xattr -dr com.apple.quarantine addons/gdserial/bin/macos-arm64/
xattr -dr com.apple.quarantine addons/gdserial/bin/macos-x86_64/
```

Relancez ensuite Godot.

## Méthode manuelle (si la commande ne fonctionne pas)

Fichiers à débloquer un par un :

**FMOD** (3 fichiers) :
1. `libGodotFmod.macos.editor.framework`
2. `libGodotFmod.macos.template_debug.framework`
3. `libGodotFmod.macos.template_release.framework`

**GdSerial** (2 fichiers) :
1. `addons/gdserial/bin/macos-arm64/libgdserial.dylib`
2. `addons/gdserial/bin/macos-x86_64/libgdserial.dylib`

Pour chacun, la procédure est la même :

1. Ouvrez le projet dans Godot — une alerte macOS apparaît pour le fichier bloqué
2. Cliquez sur **Terminé** (ne pas mettre à la corbeille)
3. Allez dans **Réglages Système → Confidentialité et sécurité**
4. Descendez dans la page, vous verrez un message mentionnant le fichier bloqué
5. Cliquez sur **Ouvrir quand même**
6. macOS vous demandera votre mot de passe ou Touch ID
7. Relancez Godot — il bloquera le fichier suivant, répétez la procédure

Après avoir autorisé tous les fichiers, Godot ouvrira le projet sans problème.

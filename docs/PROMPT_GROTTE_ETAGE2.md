# Prompt : Grotte, 2ᵉ étage + zone d'eau + nettoyage du décor

Tu travailles sur un jeu Godot **4.7.2** (GDScript, pas de C#) fait pendant un hackathon. Le projet est dans le dossier courant. Lis ce document en entier avant de toucher au code, puis travaille par étapes, avec un test à chaque étape.

## 1. Contexte du jeu (à ne pas casser)

- Jeu asymétrique à 2 joueurs sur le même écran :
  - le **joueur** cherche des morceaux de clé qu'il repère **au son** (bip de plus en plus rapide quand il s'approche) ;
  - le **piégeur** déclenche des pièges.
- Règles :
  - chrono global de 5 min (autoload `Partie`, `Scripts/partie.gd`) ;
  - mort (vide, écrasement) = retour au début du niveau (`Character.kill()` / `respawn()`) ;
  - la sortie ne s'ouvre que quand toutes les clés du niveau sont ramassées (`Scripts/game_manager.gd`, scène `Scenes/LevelRules.tscn`).
- **Vue isométrique fixe** : caméra orthographique (`Scripts/level_camera.gd`), yaw 45°, pitch 30°. La caméra regarde depuis +X/+Z. Tout le niveau doit rester visible à l'écran pour le piégeur.
- Le joueur (`Scenes/Player.tscn`, `Scripts/Player/Character.gd`) :
  - capsule de **rayon 1,65 et hauteur 7,5** (donc 3,3 de large) ;
  - vitesse **9,5 dans la Grotte** ;
  - gravité ×4 et saut `JUMP_VELOCITY = 17` : sommet du saut ≈ **3,7** au-dessus du sol, ≈ 0,88 s en l'air, portée horizontale ≈ **8,4** ;
  - sprite 2D en 8 directions (billboard Y), dont les pieds sont au bas de la capsule.
- Grotte actuelle :
  - décor généré par `tools/generer_grotte.gd` → `Scenes/Levels/Grotte.tscn` ;
  - scène jouable `Scenes/Levels/GrotteScene.tscn` ;
  - 5 galeries en serpentin, 4 clés ;
  - terrain x de -41 à 43, z de -18 à 28, surface du sol à y = **0,97** (`SOL_Y`) ;
  - caméra `target = (1, 1, 5)`, `view_size = 60`.
- Pièges de la Grotte :
  - stalactites (`Scripts/Traps/stalactites.gd`, liste `spots`, flaque sous chacune) ;
  - 3 trappes (`Scripts/Traps/trapdoor.gd`) ;
  - rocher sur une corniche (`Scripts/Traps/boulder.gd`) ;
  - tous pilotés par `Scripts/trapper.gd` (bouton principal = stalactites, touches 1/2/3 = trappes, joystick/flèches = rocher).
- Clés : `Scenes/KeyPiece.tscn` / `Scripts/key_piece.gd`. Une clé ne se ramasse que si les pieds du joueur sont à ±1,2 de sa hauteur (pas de ramassage par-dessous).
- Sons : `Sfx.play("nom")` joue `Sons/nom.wav`. Nouveaux sons à ajouter dans `tools/generer_sfx.gd` (synthèse), puis relancer l'outil.
- Commandes utiles (depuis le dossier du projet) :
  - `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/generer_grotte.gd`
  - `... --headless --path . --import` après avoir ajouté des fichiers.

**Le niveau actuel est bon : garde sa structure, son style et ses pièges. Tu ajoutes, tu ne refais pas.**

## 2. Ce qu'il faut faire

### 2.1 Un 2ᵉ étage, dans le même style, pour allonger le niveau

- But : **+30 à 40 s de parcours optimal** (aujourd'hui 53 s pour un joueur qui connaît l'emplacement des clés).
- Le 2ᵉ étage est **au-dessus** du rez-de-chaussée. Son **sol sert de plafond** au rez-de-chaussée : dalle épaisse avec dessous en roche texturée, comme les sols existants.
- Hauteur de l'étage : prévoir au moins 9 de hauteur libre entre le sol du RDC et le dessous du plafond (le joueur fait 7,5). Exemple : sol de l'étage à y ≈ 0,97 + 11.
- **Accès** :
  - au moins une montée (escalier de blocs ou rampe de rochers) et une descente, placées contre un mur du fond (nord ou ouest) ;
  - chaque marche doit faire ≤ 2 de haut pour être franchissable en sautant (sommet du saut 3,7) ;
  - pas de rampe plus raide que 40°, sinon le joueur glisse.
- **Problème de vue isométrique à régler absolument**, parce qu'un étage au-dessus cache le RDC :
  - quand le joueur est au RDC : l'étage (sol + décor + pièges) est **masqué ou très transparent**, sauf ses bords ;
  - quand le joueur est à l'étage : le RDC est **assombri** (pas caché), et la caméra monte de la hauteur d'un étage (`level_camera.gd` : déplacer `target.y` en douceur) ;
  - le piégeur doit toujours voir le joueur et les pièges proches de lui ;
  - fais-le avec un petit script générique (par ex. `Scripts/floor_visibility.gd`) : il connaît l'étage du joueur (sa hauteur) et règle la visibilité des groupes de nœuds de chaque étage.
- Contenu de l'étage, dans le même esprit que le RDC :
  - galeries ou salles reliées en serpentin ;
  - sauts au-dessus du vide (trous ≥ 4,5 de large pour qu'on ne puisse pas les enjamber, ≤ 7 pour rester sautables) ;
  - un passage d'escalade ;
  - des **stalactites** accrochées à un **plafond visible** (au moins un bord de plafond ou des poutres de roche, pour qu'elles ne flottent pas dans le vide).
- Pièges de l'étage : réutiliser les scripts existants. Les stalactites peuvent être une 2ᵉ instance de `stalactites.gd`, ou le même nœud avec plus de `spots` (et un `ceiling_y` par spot si besoin). Respecter la règle : **le joueur doit toujours pouvoir être plus rapide qu'un piège en mouvement** et avoir un temps d'alerte (≥ 0,7 s).
- Tomber dans un trou de l'étage = retour au début du niveau, comme au RDC. **Exception** : si un trou de l'étage tombe au-dessus d'un sol du RDC, le joueur atterrit au RDC. C'est autorisé seulement si c'est voulu et sans danger : pas de chute sur une trappe ni dans un gouffre du RDC.

### 2.2 Une zone d'eau où l'on peut marcher, avec une clé

- Eau **peu profonde** : on marche dedans. C'est l'inverse de la rivière de la Plaine, qui tue.
- Visuel :
  - surface d'eau semi-transparente, légèrement au-dessus du sol (≈ +0,3), avec le fond visible dessous ;
  - un shader simple (ondulation, reflets) ou un matériau avec normal map animée ;
  - bords nets (rochers, galets), quelques cristaux pour l'éclairer.
- Gameplay :
  - le joueur est **ralenti** dans l'eau (≈ 60 % de sa vitesse, via une `Area3D` qui modifie un multiplicateur dans `Character.gd`) ;
  - son de pas d'eau (ajouter `pas_eau` et `eclaboussure` dans `generer_sfx.gd`) ;
  - pas de mort ;
  - **une clé dans la zone d'eau**, par exemple sur un îlot ou un rocher au milieu.
- **Garde 4 clés au total** : le document du chef de projet demande 3 ou 4 clés pour la Grotte. Déplace une clé existante dans l'eau (de préférence celle du recoin de la 4ᵉ galerie), ou à l'étage. Le compteur se met à jour tout seul (`game_manager.gd` compte le groupe `keys`).
- La zone d'eau peut être au RDC ou à l'étage. Choisis l'endroit où elle allonge le plus le parcours sans le rendre confus.

### 2.3 Nettoyer tous les défauts de décor

Passe **tout le niveau** au crible, RDC et étage, et corrige chaque cas :

1. **Z-fighting** (deux surfaces au même endroit qui clignotent) : sols qui se chevauchent, dessus de dalle et flaques, eau et sol, trappe et sol autour. Décaler d'au moins 0,02, ou ne pas faire se chevaucher les rectangles.
2. **Objets qui flottent** : chaque rocher, stalagmite, champignon, cristal, torche et caillou doit toucher le sol ou un mur. Vérifie par raycast vers le bas depuis chaque objet. Un objet au-dessus du vide doit être supprimé ou déplacé.
3. **Objets qui traversent un mur, un sol ou un pilier** (torches, cristaux, rochers enfoncés dans un mur, stalagmites dans un pilier). Vérifie par chevauchement de boîtes englobantes (AABB) entre le décor et les collisions.
4. **Collisions sans visuel** (mur invisible) et **visuels sans collision** (on traverse un rocher) :
   - toute collision doit avoir un visuel de même taille ;
   - tout objet décoratif plus haut que 1 et placé dans le passage doit avoir une collision, ou être retiré du passage ;
   - seule exception autorisée : les limites extérieures du terrain.
5. **Textures** :
   - pas d'étirement : `uv1_triplanar` et la même échelle de texture pour une même matière ;
   - pas de couture visible ;
   - pas de matériau gris uni oublié ;
   - normal maps dans le bon sens ;
   - mêmes couleurs que le style existant (`roche()` dans `generer_grotte.gd`).
6. **Transparence** : pas de tri cassé (eau, flaques, verre). Un matériau ne doit être en mode transparent que s'il en a besoin.
7. **Lumière** :
   - pas de lumière qui « fuit » à travers un sol ou un plafond (limiter `omni_range`, activer les ombres sur les lumières qui en ont besoin) ;
   - pas de zone totalement noire sur le chemin ;
   - pas de zone surexposée.
8. **Ombres** : pas d'acné d'ombre ni d'objet qui « décolle » (*peter-panning*). Régler `shadow_bias` / `shadow_normal_bias` de la lumière directionnelle si besoin.
9. **Échelle** : décor cohérent avec le personnage (7,5 de haut). Pas de champignon géant ni de stalactite minuscule.
10. **Vue isométrique** :
    - rien de haut entre la caméra et le chemin ;
    - ce qui est haut se met contre les murs du fond (nord/ouest) ;
    - pour les séparations, garder le principe actuel : muret bas + piliers fins, on voit à travers.
11. **Lisibilité** : on doit voir au premier coup d'œil où l'on peut marcher (dessus des sols plus clair), où est le vide (noir), où l'on peut sauter, et où se trouvent les dangers (flaques sous les stalactites, trappes avec une fente au milieu).
12. **Arêtes grimpables** : le bas arrondi de la capsule accroche les arêtes. Tout ce qui ne doit pas être franchi doit dépasser le sommet du saut d'au moins 1,3 (donc ≥ 5 de haut depuis le sol). Tout ce qui doit être sauté doit faire ≤ 2.

## 3. Méthode

1. Lis `tools/generer_grotte.gd`, `Scenes/Levels/GrotteScene.tscn`, `Scripts/Traps/*.gd`, `Scripts/Player/Character.gd`, `Scripts/level_camera.gd`, `Scripts/key_piece.gd` et `Scripts/trapper.gd`.
2. Garde la logique « décor généré par l'outil » : ajoute l'étage et l'eau **dans `generer_grotte.gd`**, avec des listes de coordonnées en haut du fichier comme l'existant (`SOLS`, `BLOCS`, `MURS`…). Place les nœuds de jeu (clés, pièges, sortie) dans `GrotteScene.tscn`.
3. Code sobre : peu de commentaires, en français, noms courts, même style que les scripts existants.
4. Ajoute un outil de **vérification du décor** (par ex. `tools/verifier_decor.gd`), lancé en headless, qui liste :
   - les objets qui flottent (raycast vers le bas) ;
   - les objets qui chevauchent une collision (AABB) ;
   - les surfaces coplanaires qui se chevauchent ;
   - les collisions sans `MeshInstance3D` correspondante.
   Corrige jusqu'à ce que la liste soit vide, en dehors des exceptions documentées.
5. Teste avec un **joueur automatique** : un script de test qui pilote les actions `p1_*` vers une liste de points, et saute quand il faut. Il doit faire tout le parcours, RDC + étage + eau, ramasser les 4 clés et atteindre la sortie **sans chute**. Note le temps : il doit être d'environ **85 à 95 s**.
6. Vérifie aussi :
   - courir sans sauter vers chaque trou fait tomber ;
   - aucun mur de séparation ni bord d'étage ne peut être franchi en sautant ;
   - aucune clé en hauteur ne se ramasse depuis le dessous ;
   - le ralentissement dans l'eau fonctionne ;
   - l'étage se masque et se démasque bien selon la position du joueur.
7. Prends des **captures d'écran** (`get_viewport().get_texture().get_image().save_png(...)`) : vue d'ensemble avec le joueur au RDC, à l'étage et dans l'eau, plus des gros plans des zones retouchées. Regarde-les vraiment avant de conclure.

## 4. Critères de fin

- [ ] 2ᵉ étage jouable, accessible par une montée, avec sa redescente.
- [ ] Plafond visible et stalactites accrochées à ce plafond.
- [ ] Zone d'eau marchable avec ralentissement, sons et une clé.
- [ ] 4 clés au total, toutes atteignables, aucune ramassable par-dessous.
- [ ] Parcours optimal d'environ 85 à 95 s, terminé sans chute par le joueur automatique.
- [ ] L'outil de vérification du décor ne signale plus rien.
- [ ] Captures d'écran vérifiées : pas de z-fighting, d'objet flottant ou traversant, de texture étirée, de zone illisible.
- [ ] La Plaine et l'enchaînement Plaine → Grotte (chrono continu) fonctionnent toujours.
- [ ] Commits clairs en français. **Pas de push sans demande.**

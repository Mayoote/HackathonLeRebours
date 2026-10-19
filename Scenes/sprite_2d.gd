extends Sprite2D
# Personnage de test : flèches = déplacement, Shift = course.
# Le son FMOD est un seul événement en boucle (event:/CharacterMovement) dont le paramètre
# « CharacterMovement » choisit ce qu'on entend : Walk, Run, Fly ou Void (silence, valeur par défaut).
# Hackathon oct. 2026 : le label n'est envoyé à FMOD que quand il change (avant : 60 fois par seconde),
# l'événement est démarré une image après _ready (le temps que la banque et l'émetteur soient prêts),
# et les labels sont réglables dans l'inspecteur pour les adapter à la banque sans toucher au code.

## Movement speed in pixels per second.
@export var speed: float = 200.0
## Speed multiplier applied while holding Shift.
@export var sprint_multiplier: float = 2.5

@export var FMOD_Emitter: FmodEventEmitter2D

@export_group("Labels FMOD du paramètre CharacterMovement")
## Label envoyé quand le personnage ne bouge pas.
@export var label_immobile: String = "Void"
## Label envoyé quand le personnage marche (flèches sans Shift).
@export var label_marche: String = "Walk"
## Label envoyé quand le personnage court (Shift enfoncé).
@export var label_course: String = "Run"

var _label_courant: String = ""

func _ready() -> void:
	if FMOD_Emitter == null:
		FMOD_Emitter = $"../FmodEventEmitter2D"
	# Une image de délai : les frères placés après ce nœud (l'émetteur) n'ont pas encore reçu leur _ready.
	await get_tree().process_frame
	FMOD_Emitter.play()
	_appliquer_label(label_immobile)

func _process(delta: float) -> void:
	# Build a direction vector from arrow-key input.
	var direction := Vector2.ZERO

	if Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0

	if Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0

	if Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0

	if Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0

	# Normalize so diagonal movement isn't faster.
	if direction != Vector2.ZERO:
		direction = direction.normalized()

	# Apply sprint if either Shift key is held.
	var current_speed := speed
	var shift := Input.is_key_pressed(KEY_SHIFT)
	if shift:
		current_speed *= sprint_multiplier

	# Son : Shift = course (même à l'arrêt, pour que le test « Shift → son » soit sans ambiguïté),
	# flèches = marche, rien = silence.
	if shift:
		_appliquer_label(label_course)
	elif direction != Vector2.ZERO:
		_appliquer_label(label_marche)
	else:
		_appliquer_label(label_immobile)

	# Move the sprite.
	position += direction * current_speed * delta

func _appliquer_label(label: String) -> void:
	if label == _label_courant or FMOD_Emitter == null:
		return
	_label_courant = label
	FMOD_Emitter.set_parameter("CharacterMovement", label)

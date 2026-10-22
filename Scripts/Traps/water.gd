# Rivière : tomber dedans renvoie au début du niveau

extends Area3D


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("kill"):
		get_node("/root/Sfx").play("plouf")  # (pas "Sfx" direct : le générateur doit pouvoir compiler ce script)
		body.kill()

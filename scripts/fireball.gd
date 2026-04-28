extends Area2D

var vel := Vector2.ZERO
var grav := 400.0
var lifetime := 3.0

func _ready() -> void:
	body_entered.connect(_on_hit)

func setup(dir: int, spd := 200.0) -> void:
	vel = Vector2(dir * spd, -50)

func _physics_process(delta: float) -> void:
	vel.y += grav * delta
	position += vel * delta
	lifetime -= delta
	if lifetime <= 0 or position.y > 500: queue_free()
	if vel.y > 0 and position.y > 310:
		vel.y = -140; position.y = 310

func _on_hit(body: Node2D) -> void:
	if body.is_in_group("enemies"):
		if body.has_method("hit_by_fireball"): body.hit_by_fireball()
		queue_free()
	elif not body.is_in_group("player"):
		queue_free()

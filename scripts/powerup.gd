extends Area2D

var vel := Vector2(30, 0)
var grav := 400.0
var powerup_type := 1
var emerged := false

signal collected(type: int)

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	body_entered.connect(_on_body)
	var tw := create_tween()
	tw.tween_property(self, "position:y", position.y - 16, 0.3)
	await tw.finished
	emerged = true

func _physics_process(delta: float) -> void:
	if not emerged: return
	if powerup_type == 1:
		vel.y += grav * delta
		position += vel * delta
		if position.y > 320: vel.y = 0; position.y = 320

func _on_body(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit(powerup_type)
		queue_free()

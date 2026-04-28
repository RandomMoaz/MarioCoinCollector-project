extends Area2D

@export var value := 50
var start_y := 0.0
var time := 0.0
var collected := false

signal picked_up(val: int)

@onready var sprite: AnimatedSprite2D = $Sprite

func _ready() -> void:
	start_y = position.y
	time = randf() * TAU
	body_entered.connect(_on_body)
	sprite.play("spin")

func _process(delta: float) -> void:
	if collected: return
	time += delta * 2.5
	position.y = start_y + sin(time) * 2.0

func _on_body(body: Node2D) -> void:
	if collected: return
	if body.is_in_group("player"):
		collected = true; picked_up.emit(value)
		set_deferred("monitoring", false)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(sprite, "position:y", sprite.position.y - 16, 0.2)
		tw.tween_property(sprite, "modulate:a", 0.0, 0.2)
		await tw.finished; queue_free()

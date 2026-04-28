extends Node2D

var vel := Vector2(0, -150)

func _ready() -> void:
	var sp := Sprite2D.new()
	sp.texture = load("res://assets/items/coin_0.png")
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sp)

func _process(delta: float) -> void:
	vel.y += 400 * delta
	position += vel * delta
	modulate.a -= delta * 2.0
	if modulate.a <= 0: queue_free()

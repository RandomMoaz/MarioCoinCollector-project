extends Node2D

func _ready() -> void:
	var lbl := Label.new()
	lbl.text = "+100"
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color.GOLD)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 1)
	lbl.position = Vector2(-12, -8)
	add_child(lbl)

func _process(delta: float) -> void:
	position.y -= 30 * delta
	modulate.a -= delta * 2.5
	if modulate.a <= 0: queue_free()

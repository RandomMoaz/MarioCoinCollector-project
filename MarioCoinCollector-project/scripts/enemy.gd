extends CharacterBody2D

@export var walk_speed := 40.0
var direction := -1
var alive := true
var grav := 550.0
var enemy_type := "goomba"

signal stomped_signal
signal killed_by_fire

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var wall_ray: RayCast2D = $WallRay
@onready var floor_ray: RayCast2D = $FloorRay

func _ready() -> void:
	add_to_group("enemies")
	sprite.play("walk")
	_update_dir()

func _physics_process(delta: float) -> void:
	if not alive: return
	if not is_on_floor(): velocity.y += grav * delta
	velocity.x = direction * walk_speed
	if wall_ray.is_colliding() or (is_on_floor() and not floor_ray.is_colliding()):
		direction *= -1; _update_dir()
	move_and_slide()
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if not collider.is_in_group("player"): continue
		var player_bottom = collider.global_position.y + 6
		var my_top = global_position.y - 6
		if player_bottom < my_top + 4 and collider.velocity.y >= 0:
			continue
		collider.take_damage()

func _update_dir() -> void:
	sprite.flip_h = direction > 0
	wall_ray.target_position.x = direction * 10
	floor_ray.target_position = Vector2(direction * 8, 10)

func stomped() -> void:
	if not alive: return
	alive = false; velocity = Vector2.ZERO
	stomped_signal.emit()
	if enemy_type == "koopa":
		sprite.play("shell")
	else:
		sprite.play("squished")
	set_collision_layer_value(2, false); set_collision_mask_value(1, false)
	var t := create_tween(); t.tween_interval(0.4); t.tween_callback(queue_free)

func hit_by_fireball() -> void:
	if not alive: return
	alive = false; velocity = Vector2(0, -150)
	killed_by_fire.emit()
	set_collision_layer_value(2, false); set_collision_mask_value(1, false)
	sprite.flip_v = true
	var t := create_tween(); t.tween_interval(1.0); t.tween_callback(queue_free)

func set_speed(s: float) -> void: walk_speed = s
func set_type(t: String) -> void: enemy_type = t

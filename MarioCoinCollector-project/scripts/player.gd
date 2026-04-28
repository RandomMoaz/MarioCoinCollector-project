extends CharacterBody2D

@export var speed := 120.0
@export var jump_force := -250.0
@export var grav := 550.0
@export var max_fall := 450.0

var facing := 1
var invincible := 0.0
var char_id := "mario"
var coyote_time := 0.0
var jump_buffer := 0.0
var power_state := 0  # 0=small, 1=big(mushroom), 2=fire

signal died
signal hit_with_state(was_big: bool)
signal jumped
signal head_hit_tile(tile_pos: Vector2i)
signal shoot_fireball(pos: Vector2, dir: int)

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var stomp: Area2D = $StompArea
@onready var col_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	add_to_group("player")
	stomp.body_entered.connect(_on_stomp)

func set_character(id: String) -> void:
	char_id = id
	_update_sprite_frames()

func power_up(new_state: int) -> void:
	if new_state > power_state:
		power_state = new_state
		_update_sprite_frames()

func take_damage() -> void:
	if invincible > 0: return
	if power_state > 0:
		hit_with_state.emit(true)
		power_state = 0
		_update_sprite_frames()
		invincible = 2.0
	else:
		hit_with_state.emit(false)
		invincible = 2.0
		velocity.y = jump_force * 0.5

func _update_sprite_frames() -> void:
	var prefix := ""
	if power_state == 2: prefix = "fire_"
	var res_name := "res://resources/%s_%ssmall_frames.tres" % [char_id, prefix]
	var res = load(res_name)
	if res: sprite.sprite_frames = res

func _physics_process(delta: float) -> void:
	if is_on_floor():
		coyote_time = 0.1
	else:
		coyote_time -= delta
		velocity.y = min(velocity.y + grav * delta, max_fall)

	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.12
	else:
		jump_buffer -= delta

	var dir := Input.get_axis("move_left", "move_right")
	if dir != 0:
		velocity.x = move_toward(velocity.x, dir * speed, 800 * delta)
		facing = int(sign(dir))
		sprite.flip_h = facing < 0
	else:
		velocity.x = move_toward(velocity.x, 0, 900 * delta)

	if jump_buffer > 0 and coyote_time > 0:
		velocity.y = jump_force
		coyote_time = 0; jump_buffer = 0
		jumped.emit()
	if Input.is_action_just_released("jump") and velocity.y < jump_force * 0.4:
		velocity.y = jump_force * 0.4

	if power_state == 2 and Input.is_action_just_pressed("attack"):
		shoot_fireball.emit(global_position + Vector2(facing * 10, -4), facing)

	if not is_on_floor():
		sprite.play("jump" if velocity.y < 0 else "fall")
	elif abs(velocity.x) > 10:
		sprite.play("run")
	else:
		sprite.play("idle")

	if invincible > 0:
		invincible -= delta
		sprite.modulate.a = 0.3 if fmod(invincible, 0.15) < 0.075 else 1.0
		if invincible <= 0: sprite.modulate.a = 1.0

	move_and_slide()

	if is_on_ceiling():
		var head_pos := global_position + Vector2(0, -10)
		var tp := Vector2i(int(head_pos.x) / 16, int(head_pos.y) / 16)
		head_hit_tile.emit(tp)

	if global_position.y > 500:
		died.emit()

func _on_stomp(body: Node2D) -> void:
	if body.is_in_group("enemies") and velocity.y >= 0:
		if body.has_method("stomped"): body.stomped()
		velocity.y = jump_force * 0.45

extends Node2D

const TILE := 16
const QUESTION_SRC := 3
const USED_SRC := 4
const BRICK_SRC := 2

enum GS { CHAR_SELECT, PLAYING, GAME_OVER, LEVEL_DONE, WIN }
var state := GS.CHAR_SELECT
var score := 0
var coins_collected := 0
var total_coins := 0
var lives := 3
var kills := 0
var current_level := 1
var max_levels := 32
var selected_char := 0
var level_time := 0.0
var level_time_limit := 200.0
var attempts := 0
var char_ids := ["mario", "luigi", "toad", "rosa"]
var char_names := ["Mario", "Luigi", "Toad", "Rosie"]
var char_stats := [
	{"speed": 120, "jump": -250, "desc": "Balanced"},
	{"speed": 140, "jump": -240, "desc": "Faster"},
	{"speed": 110, "jump": -270, "desc": "High Jump"},
	{"speed": 130, "jump": -260, "desc": "Agile"},
]

var player_scene: PackedScene
var coin_scene: PackedScene
var enemy_scene: PackedScene
var block_coin_scn: PackedScene
var score_popup_scn: PackedScene
var fireball_scene: PackedScene
var powerup_scene: PackedScene
var flagpole_scene: PackedScene

var player: CharacterBody2D
var tilemap: TileMap
var camera: Camera2D
var coins_node: Node2D
var enemies_node: Node2D
var items_node: Node2D
var hud_layer: CanvasLayer
var world_lbl: Label; var coins_lbl: Label; var score_lbl: Label
var lives_lbl: Label; var kills_lbl: Label; var power_lbl: Label; var timer_lbl: Label; var attempts_lbl: Label
var overlay: ColorRect; var ov_title: Label; var ov_sub: Label; var ov_hint: Label
var bg: ColorRect

var sfx := {}
var char_select_node: Control
var char_labels: Array[Label] = []
var char_desc_label: Label
var char_sprites: Array[AnimatedSprite2D] = []

var theme_colors := {
	0: Color("5c94fc"), 1: Color("14142e"), 2: Color("87ceeb"), 3: Color("282830"),
	4: Color("320f03"), 5: Color("1a0a30"), 6: Color("2a4a1a"), 7: Color("4a1020"),
}
var world_names := ["Grassland", "Underground", "Sky World", "Dark Castle", "Lava Depths", "Shadow Realm", "Deep Forest", "Final Kingdom"]

func _ready() -> void:
	player_scene = load("res://scenes/player.tscn")
	coin_scene = load("res://scenes/coin.tscn")
	enemy_scene = load("res://scenes/enemy.tscn")
	block_coin_scn = load("res://scenes/block_coin.tscn")
	score_popup_scn = load("res://scenes/score_popup.tscn")
	fireball_scene = load("res://scenes/fireball.tscn")
	powerup_scene = load("res://scenes/powerup.tscn")
	flagpole_scene = load("res://scenes/flagpole.tscn")
	_setup_sounds()
	_build_ui()
	_build_char_select()

func _setup_sounds() -> void:
	for sn in ["jump","jump_big","coin","stomp","hit","block","brick_break","powerup","fireball","kick","flagpole","levelup","gameover","select","pipe","shrink"]:
		var path := "res://assets/sfx/%s.wav" % sn
		if ResourceLoader.exists(path):
			var asp := AudioStreamPlayer.new()
			asp.stream = load(path); asp.volume_db = -5
			add_child(asp); sfx[sn] = asp

func play_sfx(s: String) -> void:
	if sfx.has(s): sfx[s].play()

func _build_ui() -> void:
	bg = ColorRect.new(); bg.z_index = -10; bg.color = Color("5c94fc")
	bg.size = Vector2(10000, 1200); bg.position = Vector2(-500, -600); add_child(bg)

	tilemap = TileMap.new(); tilemap.name = "TileMap"
	var ts := TileSet.new(); ts.tile_size = Vector2i(TILE, TILE); ts.add_physics_layer()
	var tile_names := ["ground_top","ground_fill","brick","question","used_block","pipe_top","pipe_body","stone","castle"]
	for i in range(tile_names.size()):
		var tex_path := "res://assets/tiles/%s.png" % tile_names[i]
		if not ResourceLoader.exists(tex_path): continue
		var src := TileSetAtlasSource.new()
		src.texture = load(tex_path)
		src.texture_region_size = Vector2i(TILE, TILE); ts.add_source(src, i)
		src.create_tile(Vector2i(0,0))
		var td := src.get_tile_data(Vector2i(0,0),0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(0,0),Vector2(TILE,0),Vector2(TILE,TILE),Vector2(0,TILE)]))
	tilemap.tile_set = ts; add_child(tilemap)

	coins_node = Node2D.new(); coins_node.name = "Coins"; add_child(coins_node)
	enemies_node = Node2D.new(); enemies_node.name = "Enemies"; add_child(enemies_node)
	items_node = Node2D.new(); items_node.name = "Items"; add_child(items_node)

	camera = Camera2D.new(); camera.zoom = Vector2(2.5, 2.5)
	camera.limit_top = -50; camera.limit_bottom = 360; camera.limit_left = 0
	camera.position_smoothing_enabled = true; camera.position_smoothing_speed = 6.0
	add_child(camera)

	hud_layer = CanvasLayer.new(); add_child(hud_layer)
	var hbox := HBoxContainer.new(); hbox.position = Vector2(4, 2)
	hbox.add_theme_constant_override("separation", 10); hud_layer.add_child(hbox)
	for n in ["world_lbl","coins_lbl","score_lbl","lives_lbl","kills_lbl","power_lbl","timer_lbl","attempts_lbl"]:
		var l := Label.new(); l.add_theme_font_size_override("font_size", 9)
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 2)
		hbox.add_child(l); set(n, l)

	overlay = ColorRect.new(); overlay.color = Color(0,0,0,0.65)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE; hud_layer.add_child(overlay)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8); overlay.add_child(vbox)
	ov_title = Label.new(); ov_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov_title.add_theme_font_size_override("font_size", 18)
	ov_title.add_theme_color_override("font_color", Color.GOLD)
	ov_title.add_theme_color_override("font_outline_color", Color.BLACK)
	ov_title.add_theme_constant_override("outline_size", 3); vbox.add_child(ov_title)
	ov_sub = Label.new(); ov_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov_sub.add_theme_font_size_override("font_size", 10)
	ov_sub.add_theme_color_override("font_color", Color.WHITE); vbox.add_child(ov_sub)
	ov_hint = Label.new(); ov_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov_hint.add_theme_font_size_override("font_size", 9)
	ov_hint.add_theme_color_override("font_color", Color.GOLD); vbox.add_child(ov_hint)
	overlay.visible = false

func _build_char_select() -> void:
	char_select_node = Control.new()
	char_select_node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_layer.add_child(char_select_node)
	
	# Full screen dark background
	var bg2 := ColorRect.new()
	bg2.color = Color(0, 0, 0, 0.8)
	bg2.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	char_select_node.add_child(bg2)
	
	# Main vertical layout centered on screen
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 12)
	char_select_node.add_child(main_vbox)
	
	# Title
	var title := Label.new()
	title.text = "CHOOSE YOUR CHARACTER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.GOLD)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)
	main_vbox.add_child(title)
	
	# Characters row
	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(hbox)
	
	for i in range(4):
		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_theme_constant_override("separation", 4)
		hbox.add_child(vb)
		
		var frame := ColorRect.new()
		frame.custom_minimum_size = Vector2(52, 52)
		frame.color = Color(0.2, 0.2, 0.3, 0.8)
		vb.add_child(frame)
		
		var sp := AnimatedSprite2D.new()
		sp.sprite_frames = load("res://resources/%s_small_frames.tres" % char_ids[i])
		sp.animation = "idle"
		sp.autoplay = "idle"
		sp.position = Vector2(26, 35)
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.scale = Vector2(2.5, 2.5)
		frame.add_child(sp)
		char_sprites.append(sp)
		
		var nl := Label.new()
		nl.text = char_names[i]
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 10)
		nl.add_theme_color_override("font_color", Color.WHITE)
		vb.add_child(nl)
		char_labels.append(nl)
	
	# Description
	char_desc_label = Label.new()
	char_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_desc_label.add_theme_font_size_override("font_size", 10)
	char_desc_label.add_theme_color_override("font_color", Color.WHITE)
	main_vbox.add_child(char_desc_label)
	
	# Controls hint
	var hint := Label.new()
	hint.text = "Left/Right = Choose  |  ENTER = Start  |  X/Z = Shoot Fireballs"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 8)
	hint.add_theme_color_override("font_color", Color.GOLD)
	main_vbox.add_child(hint)
	
	_update_char_select()

func _update_char_select() -> void:
	for i in range(4):
		char_labels[i].add_theme_color_override("font_color", Color.GOLD if i == selected_char else Color.WHITE)
		char_sprites[i].get_parent().color = Color(0.5, 0.4, 0.1, 0.9) if i == selected_char else Color(0.2, 0.2, 0.3, 0.8)
	char_desc_label.text = "%s — %s" % [char_names[selected_char], char_stats[selected_char].desc]

func _show_ov(t: String, s: String, h: String) -> void:
	overlay.visible = true; ov_title.text = t; ov_sub.text = s; ov_hint.text = h
func _hide_ov() -> void: overlay.visible = false

func _update_hud() -> void:
	var w := ((current_level-1)/4)+1; var l := ((current_level-1)%4)+1
	var wn: String = world_names[(w-1) % world_names.size()]
	world_lbl.text = "W%d-%d %s" % [w,l,wn]
	coins_lbl.text = "Coins:%d/%d" % [coins_collected, total_coins]
	score_lbl.text = "%d" % score
	lives_lbl.text = "x%d" % lives
	kills_lbl.text = "K:%d" % kills
	var pname := "Small"
	if player and is_instance_valid(player):
		pname = ["Small", "Super", "Fire"][player.power_state]
	power_lbl.text = pname
	var time_left := maxi(0, int(level_time_limit - level_time))
	timer_lbl.text = "T:%d" % time_left
	if time_left <= 30 and time_left > 0:
		timer_lbl.add_theme_color_override("font_color", Color.RED)
	else:
		timer_lbl.add_theme_color_override("font_color", Color.WHITE)
	attempts_lbl.text = "Att:%d" % attempts

func _input(event: InputEvent) -> void:
	if state == GS.CHAR_SELECT:
		if event.is_action_pressed("move_right") or event.is_action_pressed("ui_right"):
			selected_char = (selected_char + 1) % 4; play_sfx("select"); _update_char_select()
		elif event.is_action_pressed("move_left") or event.is_action_pressed("ui_left"):
			selected_char = (selected_char + 3) % 4; play_sfx("select"); _update_char_select()
		elif event.is_action_pressed("ui_accept"):
			play_sfx("select"); _start_game()
		return
	if event.is_action_pressed("ui_accept"):
		match state:
			GS.GAME_OVER: _restart()
			GS.LEVEL_DONE: _next_level()
			GS.WIN: state = GS.CHAR_SELECT; char_select_node.visible = true; _hide_ov()
	if event.is_action_pressed("ui_cancel") and state == GS.PLAYING:
		get_tree().reload_current_scene()

func _start_game() -> void:
	char_select_node.visible = false
	score = 0; lives = 3; kills = 0; attempts = 0; current_level = 1; _load_level()

func _restart() -> void:
	score = 0; lives = 3; kills = 0; attempts = 0; current_level = 1; _load_level()

func _next_level() -> void:
	current_level += 1
	if current_level > max_levels:
		state = GS.WIN; play_sfx("levelup")
		_show_ov("YOU WIN!", "All 32 levels complete!\nScore: %d  Kills: %d  Attempts: %d" % [score, kills, attempts], "Press ENTER to play again")
		return
	_load_level()

func _load_level() -> void:
	state = GS.PLAYING; coins_collected = 0; _hide_ov()
	level_time = 0.0
	level_time_limit = 200.0 + (32 - current_level) * 3.0  # easier levels get more time
	attempts += 1

	for c in coins_node.get_children(): c.queue_free()
	for c in enemies_node.get_children(): c.queue_free()
	for c in items_node.get_children(): c.queue_free()
	for c in get_children():
		if c.name.begins_with("BlockCoin") or c.name.begins_with("ScorePopup") or c.name.begins_with("Fireball") or c.name.begins_with("Flagpole"):
			c.queue_free()
	if player and is_instance_valid(player): player.queue_free()
	tilemap.clear()

	var world_idx := ((current_level-1)/4) % 8
	bg.color = theme_colors.get(world_idx, Color("5c94fc"))

	var map_w := 70 + current_level * 5
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("lvl_%d" % current_level)
	var ground_y := 20

	# Gaps — none in first 3 levels
	var gaps := []
	if current_level > 3:
		var gc := mini(current_level - 2, 12)
		for gi in range(gc):
			var gx := rng.randi_range(14, map_w - 14)
			var gw := rng.randi_range(2, mini(2 + current_level / 8, 5))
			var ok := true
			for eg in gaps:
				if abs(gx - eg.x) < eg.w + 8: ok = false; break
			if ok: gaps.append({"x": gx, "w": gw})

	# Ground
	for x in range(map_w):
		var is_gap := false
		for g in gaps:
			if x >= g.x and x < g.x + g.w: is_gap = true; break
		if is_gap: continue
		tilemap.set_cell(0, Vector2i(x, ground_y), 0, Vector2i(0,0))
		for dy in range(1, 3):
			tilemap.set_cell(0, Vector2i(x, ground_y + dy), 1, Vector2i(0,0))

	# Platforms
	for pi in range(mini(6 + current_level, 40)):
		var ppx := rng.randi_range(4, map_w - 6)
		var ppy := rng.randi_range(ground_y - 8, ground_y - 3)
		var ppw := rng.randi_range(2, 5)
		for dx in range(ppw):
			var q_chance := 0.35 if current_level < 8 else 0.15
			var tid := QUESTION_SRC if rng.randf() < q_chance else BRICK_SRC
			tilemap.set_cell(0, Vector2i(ppx + dx, ppy), tid, Vector2i(0,0))

	# Pipes
	if current_level > 2:
		for ppi in range(mini(current_level / 2, 10)):
			var ppx := rng.randi_range(12, map_w - 14)
			var pph := rng.randi_range(2, mini(2 + current_level / 6, 4))
			if tilemap.get_cell_source_id(0, Vector2i(ppx, ground_y)) == -1: continue
			tilemap.set_cell(0, Vector2i(ppx, ground_y - pph), 5, Vector2i(0,0))
			tilemap.set_cell(0, Vector2i(ppx + 1, ground_y - pph), 5, Vector2i(0,0))
			for dy in range(1, pph):
				tilemap.set_cell(0, Vector2i(ppx, ground_y - pph + dy), 6, Vector2i(0,0))
				tilemap.set_cell(0, Vector2i(ppx + 1, ground_y - pph + dy), 6, Vector2i(0,0))

	# End staircase + flagpole
	var stair_x := map_w - 12
	for step in range(8):
		for dy in range(step + 1):
			tilemap.set_cell(0, Vector2i(stair_x + step, ground_y - 1 - dy), 7, Vector2i(0,0))

	var fp := flagpole_scene.instantiate()
	fp.name = "Flagpole_%d" % current_level
	fp.position = Vector2((stair_x + 9) * TILE + 8, (ground_y - 1) * TILE)
	add_child(fp); fp.reached.connect(_on_flagpole)

	# Player
	player = player_scene.instantiate()
	player.position = Vector2(48, (ground_y - 2) * TILE)
	var stats = char_stats[selected_char]
	player.speed = stats.speed; player.jump_force = stats.jump
	add_child(player)
	player.set_character(char_ids[selected_char])
	player.died.connect(_on_died)
	player.hit_with_state.connect(_on_hit)
	player.jumped.connect(_on_jump)
	player.head_hit_tile.connect(_on_head_hit)
	player.shoot_fireball.connect(_on_shoot_fireball)
	camera.limit_right = map_w * TILE

	# Coins
	for ci in range(mini(8 + current_level * 2, 50)):
		var cx := rng.randi_range(3, map_w - 6)
		var cy := rng.randi_range(ground_y - 6, ground_y - 2)
		for yy in range(cy, ground_y + 1):
			if tilemap.get_cell_source_id(0, Vector2i(cx, yy)) != -1:
				cy = yy - 2; break
		if cy < 3 or cy >= ground_y: continue
		if tilemap.get_cell_source_id(0, Vector2i(cx, cy)) != -1: continue
		var c = coin_scene.instantiate()
		c.position = Vector2(cx * TILE + 8, cy * TILE + 8)
		coins_node.add_child(c); c.picked_up.connect(_on_coin)
	total_coins = coins_node.get_child_count()

	# Enemies — mix goombas and koopas
	for ei in range(mini(maxi(1, current_level - 1), 22)):
		var ex := rng.randi_range(16, map_w - 12)
		if tilemap.get_cell_source_id(0, Vector2i(ex, ground_y)) == -1: continue
		var e = enemy_scene.instantiate()
		e.position = Vector2(ex * TILE, (ground_y - 1) * TILE)
		var spd := 25.0 + current_level * 2.0
		if rng.randf() < 0.03 * current_level: spd *= 1.4
		e.set_speed(spd)
		if current_level >= 4 and rng.randf() < 0.3:
			e.set_type("koopa")
			e.get_node("Sprite").sprite_frames = load("res://resources/koopa_frames.tres")
		e.stomped_signal.connect(_on_stomp_enemy)
		e.killed_by_fire.connect(_on_fire_kill)
		enemies_node.add_child(e)

	_update_hud()

func _process(_d: float) -> void:
	if state != GS.PLAYING: return
	if player and is_instance_valid(player):
		camera.global_position = player.global_position + Vector2(30 * player.facing, -12)
	# Timer countdown
	level_time += _d
	if level_time >= level_time_limit:
		# Time's up — lose a life
		if player and is_instance_valid(player):
			player.died.emit()
	_update_hud()

func _on_flagpole() -> void:
	if state != GS.PLAYING: return
	play_sfx("flagpole")
	var time_bonus := maxi(0, int(level_time_limit - level_time)) * 5
	score += current_level * 200 + 500 + time_bonus
	state = GS.LEVEL_DONE
	var w := ((current_level-1)/4)+1; var l := ((current_level-1)%4)+1
	_show_ov("LEVEL COMPLETE!", "W%d-%d cleared!\nLevel Bonus: +%d  Time Bonus: +%d\nScore: %d" % [w,l,current_level*200+500,time_bonus,score], "Press ENTER for next level")

func _on_head_hit(tile_pos: Vector2i) -> void:
	for dx in range(-1, 2):
		for dy in range(0, 2):
			var check := Vector2i(tile_pos.x + dx, tile_pos.y - dy)
			var src_id := tilemap.get_cell_source_id(0, check)
			if src_id == QUESTION_SRC:
				_hit_question_block(check); return
			elif src_id == BRICK_SRC and player.power_state > 0:
				_break_brick(check); return

func _hit_question_block(pos: Vector2i) -> void:
	tilemap.set_cell(0, pos, USED_SRC, Vector2i(0, 0))
	play_sfx("block")
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = hash("block_%d_%d_%d" % [pos.x, pos.y, current_level])
	var roll := rng2.randf()
	if roll < 0.12 and current_level >= 5:
		_spawn_powerup(pos, 2)
	elif roll < 0.30:
		_spawn_powerup(pos, 1)
	else:
		var bc = block_coin_scn.instantiate()
		bc.name = "BlockCoin_%d_%d" % [pos.x, pos.y]
		bc.position = Vector2(pos.x * TILE + 8, pos.y * TILE - 4)
		add_child(bc)
		score += 100; coins_collected += 1; total_coins += 1
		play_sfx("coin")

func _spawn_powerup(pos: Vector2i, type: int) -> void:
	var pu = powerup_scene.instantiate()
	pu.position = Vector2(pos.x * TILE + 8, pos.y * TILE)
	pu.powerup_type = type
	if type == 2:
		pu.get_node("Sprite").texture = load("res://assets/items/fire_flower.png")
	pu.collected.connect(_on_powerup_collected)
	items_node.add_child(pu)

func _break_brick(pos: Vector2i) -> void:
	tilemap.erase_cell(0, pos)
	play_sfx("brick_break"); score += 50

func _on_powerup_collected(type: int) -> void:
	if player and is_instance_valid(player):
		player.power_up(type); play_sfx("powerup"); score += 1000

func _on_shoot_fireball(pos: Vector2, dir: int) -> void:
	play_sfx("fireball")
	var fb = fireball_scene.instantiate()
	fb.name = "Fireball_%d" % randi()
	fb.position = pos; fb.setup(dir)
	add_child(fb)

func _on_coin(val: int) -> void:
	coins_collected += 1; score += val; play_sfx("coin")
	var remaining := 0
	for c in coins_node.get_children():
		if not c.collected: remaining += 1
	if remaining <= 0 and coins_node.get_child_count() > 0:
		score += 500

func _on_hit(was_big: bool) -> void:
	if was_big:
		play_sfx("shrink")
	else:
		lives -= 1; play_sfx("hit")
		if lives <= 0:
			state = GS.GAME_OVER; play_sfx("gameover")
			_show_ov("GAME OVER", "Score: %d  Attempts: %d\nReached Level %d" % [score, attempts, current_level], "Press ENTER to restart")

func _on_died() -> void:
	lives -= 1; play_sfx("hit")
	if lives <= 0:
		state = GS.GAME_OVER; play_sfx("gameover")
		_show_ov("GAME OVER", "Score: %d  Attempts: %d\nReached Level %d" % [score, attempts, current_level], "Press ENTER to restart")
	elif player and is_instance_valid(player):
		player.position = Vector2(48, 18 * TILE)
		player.velocity = Vector2.ZERO; player.invincible = 2.0

func _on_jump() -> void:
	play_sfx("jump" if player.power_state == 0 else "jump_big")

func _on_stomp_enemy() -> void:
	play_sfx("stomp"); score += 100; kills += 1

func _on_fire_kill() -> void:
	play_sfx("stomp"); score += 200; kills += 1

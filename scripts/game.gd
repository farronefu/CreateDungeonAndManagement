extends Node2D

const Sim = preload("res://scripts/simulation.gd")
const FONT = preload("res://assets/NotoSansJP.otf")
const View = preload("res://scripts/garden_view.gd")
var presentation = View.new()
const Visuals = preload("res://scripts/action_visuals.gd")
var visuals = Visuals.new()
var result_elapsed: float = 0
const RESULT_DELAY = 1.4
const TILE = 40
const VISIBLE = Vector2i(24, 10)
const MAP = Rect2(0, 136, 960, 400)
const INK = Color("dce7db")
const MUTED = Color("82958f")
const GOLD = Color("eebf63")
const GREEN = Color("83c59a")
const RED = Color("ec8a7b")
const KINDS = ["sprout", "beetle", "warden", "knight", "healer", "heart", "egg"]
const PREP_SECONDS = 150.0
const RUNNING_STATES = ["prepare", "battle"]
var sim: GardenSimulation
var state: String = "title"
var previous_state: String = "prepare"
var camera = Vector2i(18, 0)
var view_target: String = "cursor"
var lb_next_hero: bool = true
var accumulator: float = 0.0
var state_timer: float = 0.0
var animation: float = 0.0
var held_direction = Vector2i.ZERO
var repeat_timer: float = 0.0
var pause_choice: int = 0
var sounds: Dictionary = {}
var sound_player: AudioStreamPlayer
var control_name: String = "コントローラー未接続 / キーボード使用可"
var muted: bool = false

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	setup_inputs()
	sim = Sim.new()
	sound_player = AudioStreamPlayer.new()
	sound_player.volume_db = -8
	add_child(sound_player)
	for name in ["dig", "confirm", "alert", "win"]:
		sounds[name] = load("res://assets/" + name + ".wav")
	Input.joy_connection_changed.connect(controller_changed)
	refresh_controller()
	if OS.get_cmdline_user_args().has("--preview"):
		preview_scene()
	if OS.get_cmdline_user_args().has("--screenshot"):
		preview_scene()
		await get_tree().process_frame
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://../../preview.png")
		get_tree().quit()

func setup_inputs() -> void:
	var bindings = {
		"north": [JOY_BUTTON_DPAD_UP, KEY_UP], "south": [JOY_BUTTON_DPAD_DOWN, KEY_DOWN],
		"west": [JOY_BUTTON_DPAD_LEFT, KEY_LEFT], "east": [JOY_BUTTON_DPAD_RIGHT, KEY_RIGHT],
		"dig": [JOY_BUTTON_X, KEY_X], "confirm": [JOY_BUTTON_A, KEY_ENTER],
		"back": [JOY_BUTTON_B, KEY_ESCAPE], "summon": [JOY_BUTTON_Y, KEY_Y],
		"focus": [JOY_BUTTON_LEFT_SHOULDER, KEY_TAB], "pause_game": [JOY_BUTTON_START, KEY_P],
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var joy = InputEventJoypadButton.new()
		joy.button_index = bindings[action][0]
		InputMap.action_add_event(action, joy)
		var key = InputEventKey.new()
		key.physical_keycode = bindings[action][1]
		InputMap.action_add_event(action, key)

func controller_changed(_device: int, connected: bool) -> void:
	refresh_controller()
	if not connected and state in ["prepare", "battle", "placement"]:
		previous_state = state
		state = "paused"
		pause_choice = 0

func refresh_controller() -> void:
	var devices = Input.get_connected_joypads()
	if not devices.is_empty():
		control_name = "接続中 / " + Input.get_joy_name(devices[0]).left(22)
	else:
		control_name = "コントローラー未接続 / キーボード使用可"

func restart() -> void:
	sim = Sim.new()
	state = "prepare"
	accumulator = 0
	state_timer = 0
	camera = Vector2i(18, 0)
	view_target = "cursor"
	lb_next_hero = true
	held_direction = Vector2i.ZERO
	visuals.reset()
	result_elapsed = 0
	play_sound("confirm")

func _process(delta: float) -> void:
	if state in RUNNING_STATES:
		animation += delta
		visuals.update(delta)
	elif state in ["won", "lost"]:
		result_elapsed += delta
		visuals.update(minf(delta,maxf(0,RESULT_DELAY-(result_elapsed-delta))))
	if state == "arrival":
		state_timer += delta
	if state == "arrival" and state_timer >= 2.2:
		state = "placement"
		sim.notice = "入口につながる通路に、Aで深庭の主を配置。"
	if state in ["prepare", "battle", "placement"]:
		var direction = input_direction()
		if direction != held_direction:
			held_direction = direction
			repeat_timer = 0.25
			if direction != Vector2i.ZERO:
				move_cursor(direction)
		elif direction != Vector2i.ZERO:
			repeat_timer -= delta
			if repeat_timer <= 0:
				repeat_timer += 0.1
				move_cursor(direction)
	advance_time(delta)
	queue_redraw()

func advance_time(delta: float) -> void:
	# Only these two phases advance ecology, combat, hunger and reproduction.
	# Future upgrade and transition screens are stopped by default.
	if state not in RUNNING_STATES:
		accumulator = 0
		return
	accumulator += minf(delta, 0.25)
	while accumulator >= Sim.STEP:
		accumulator -= Sim.STEP
		sim.tick(Sim.STEP, state == "battle")
		visuals.observe(sim)
		if state == "prepare" and sim.elapsed >= PREP_SECONDS:
			arrive()
			break
		if not sim.outcome.is_empty():
			state = sim.outcome
			if state == "won" and not sim.heroes.is_empty():
				view_target = "cursor"
				center_camera(sim.heroes[-1].pos,true)
			result_elapsed = 0
			play_sound("win" if state == "won" else "alert")
			break
	if not sim.events.is_empty():
		play_sound("alert")
		sim.events.clear()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("pause_game") or event.is_action_pressed("back"):
		if state == "paused":
			state = previous_state
		elif state in ["prepare", "battle", "placement"]:
			previous_state = state
			state = "paused"
			pause_choice = 0
		return
	if state == "paused":
		if event.is_action_pressed("north"):
			pause_choice = posmod(pause_choice - 1, 4)
		if event.is_action_pressed("south"):
			pause_choice = (pause_choice + 1) % 4
		if event.is_action_pressed("confirm"):
			match pause_choice:
				0: state = previous_state
				1: restart()
				2: muted = not muted
				3: get_tree().quit()
		return
	if state == "title" or state in ["won", "lost"]:
		if state in ["won", "lost"] and result_elapsed < RESULT_DELAY:
			return
		if event.is_action_pressed("confirm"):
			restart()
		return
	if state == "arrival":
		return
	if event.is_action_pressed("focus"):
		toggle_focus()
	if state == "placement":
		if event.is_action_pressed("confirm"):
			if sim.can_place(sim.cursor):
				sim.start_battle(sim.cursor)
				visuals.observe(sim)
				view_target = "hero"
				center_camera(sim.entrance,true)
				state = "battle"
				play_sound("alert")
			else:
				sim.notice = "入口につながる通路を選んでください。"
		return
	if state in RUNNING_STATES:
		if event.is_action_pressed("dig"):
			try_dig()
		if state == "prepare" and event.is_action_pressed("summon"):
			arrive()

func arrive() -> void:
	state = "arrival"
	state_timer = 0
	accumulator = 0
	play_sound("alert")

func input_direction() -> Vector2i:
	for action in ["north", "south", "west", "east"]:
		if Input.is_action_just_pressed(action):
			return {"north": Vector2i.UP, "south": Vector2i.DOWN, "west": Vector2i.LEFT, "east": Vector2i.RIGHT}[action]
	if held_direction != Vector2i.ZERO:
		var current_action = {Vector2i.UP: "north", Vector2i.DOWN: "south", Vector2i.LEFT: "west", Vector2i.RIGHT: "east"}[held_direction]
		if Input.is_action_pressed(current_action):
			return held_direction
	if Input.is_action_pressed("north") or Input.is_action_pressed("south"):
		return Vector2i(0, int(Input.is_action_pressed("south")) - int(Input.is_action_pressed("north")))
	return Vector2i(int(Input.is_action_pressed("east")) - int(Input.is_action_pressed("west")), 0)

func move_cursor(direction: Vector2i) -> void:
	sim.cursor = (sim.cursor + direction).clamp(Vector2i.ZERO, Vector2i(Sim.WIDTH - 1, sim.height - 1))
	view_target = "cursor"
	center_camera(sim.cursor, false)
	if Input.is_action_pressed("dig") and state in RUNNING_STATES:
		try_dig()

func try_dig() -> void:
	if sim.dig(sim.cursor):
		play_sound("dig")
		visuals.emit("dig", Vector2(sim.cursor))
		visuals.observe(sim)
	elif sim.power == 0:
		sim.notice = "掘削力が尽きた。生態系の防衛を見守ろう。"

func toggle_focus() -> void:
	for attempt in range(2):
		view_target = "hero" if lb_next_hero else "monarch"
		lb_next_hero = not lb_next_hero
		var p = target_position()
		if p.x >= 0:
			center_camera(p, true)
			return
	view_target = "cursor"

func target_position() -> Vector2i:
	if view_target == "monarch":
		return sim.monarch
	if view_target == "hero":
		for h in sim.heroes:
			if not h.dead and h.id == sim.carrier:
				return h.pos
		for h in sim.heroes:
			if not h.dead:
				return h.pos
	return Vector2i(-1, -1)

func center_camera(p: Vector2i, centered: bool) -> void:
	if centered:
		camera = p - Vector2i(VISIBLE.x / 2, VISIBLE.y / 2)
	else:
		if p.x < camera.x + 2: camera.x = p.x - 2
		if p.x >= camera.x + VISIBLE.x - 2: camera.x = p.x - VISIBLE.x + 3
		if p.y < camera.y + 2: camera.y = p.y - 2
		if p.y >= camera.y + VISIBLE.y - 2: camera.y = p.y - VISIBLE.y + 3
	camera = camera.clamp(Vector2i.ZERO, Vector2i(Sim.WIDTH, sim.height) - VISIBLE)

func play_sound(name: String) -> void:
	if not muted and is_instance_valid(sound_player):
		sound_player.stream = sounds[name]
		sound_player.play()

func text_at(s: String, p: Vector2, size: int = 14, color: Color = INK) -> void:
	draw_string(FONT, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func panel(rect: Rect2, fill: Color = Color("14252c")) -> void:
	draw_rect(rect, fill)
	draw_rect(rect, Color("31453f"), false, 1)

func _draw() -> void:
	if sim == null:
		return
	presentation.render(self)
	if state == "title": draw_title()
	elif state == "paused": draw_pause()
	elif state == "arrival": draw_arrival()
	elif state in ["won", "lost"] and result_elapsed >= RESULT_DELAY: draw_result()

func screen_pos(p: Vector2i) -> Vector2:
	return MAP.position + Vector2((p - camera) * TILE)

func on_screen(p: Vector2i) -> bool:
	return p.x >= camera.x and p.x < camera.x + VISIBLE.x and p.y >= camera.y and p.y < camera.y + VISIBLE.y

func overlay(rect: Rect2) -> void:
	draw_rect(Rect2(0, 0, 960, 600), Color(0.015, 0.035, 0.045, 0.72))
	panel(rect, Color("12272d"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 3)), GOLD)

func draw_title() -> void:
	overlay(Rect2(125, 85, 710, 440))
	text_at("A LIVING DUNGEON", Vector2(168, 126), 12, GOLD)
	text_at("深 庭", Vector2(168, 189), 48)
	text_at("土を掘る。命が巡る。侵入者を迎え撃つ。", Vector2(169, 228), 18, GREEN)
	text_at("01  根のゆりかご", Vector2(169, 271), 15)
	text_at("光る土から生き物が生まれ、捕食で強い守りが育ちます。", Vector2(169, 305), 14, MUTED)
	text_at("主を奥へ配置し、連れ去られたら出口までに救出しましょう。", Vector2(169, 332), 14, MUTED)
	for i in range(3):
		presentation.art.draw(self, KINDS[i], Vector2(648+i*50,190), animation)
	text_at("十字キー  移動     X  掘削     LB  視点切替", Vector2(169, 383), 15)
	text_at("X を押しながら十字キーで連続掘り", Vector2(169, 411), 13, GOLD)
	draw_rect(Rect2(168, 443, 282, 43), Color("25463f"))
	text_at("A / Enter   庭をひらく", Vector2(189, 471), 17)
	text_at(control_name, Vector2(467, 470), 10, MUTED)

func draw_pause() -> void:
	overlay(Rect2(270, 130, 420, 348))
	text_at("一時停止", Vector2(310, 181), 28)
	text_at("生態系・戦闘・タイマーは停止中", Vector2(310, 211), 13, MUTED)
	var choices = ["続ける", "最初からやり直す", "サウンド : " + ("OFF" if muted else "ON"), "ゲームを終了"]
	for i in range(4):
		if i == pause_choice: draw_rect(Rect2(302, 232 + i * 42, 352, 36), Color("29463e"))
		text_at(("›  " if i == pause_choice else "   ") + choices[i], Vector2(316, 257 + i * 42), 16, GOLD if i == pause_choice else INK)
	text_at("十字 選択    A 決定    B 戻る", Vector2(310, 451), 12, MUTED)

func draw_arrival() -> void:
	var slide = clampf(state_timer / 0.25, 0, 1)
	var y = lerpf(270, 222, slide)
	draw_rect(Rect2(0,y,960,132),Color(0.07,0.09,0.11,0.94))
	draw_rect(Rect2(0,y,960,2),RED)
	draw_rect(Rect2(0,y+130,960,2),GOLD)
	presentation.art.draw(self,"knight",Vector2(258,y+93),state_timer,"move_right")
	text_at("侵入者、到来。",Vector2(363,y+53),29,GOLD)
	text_at("鉄の測量士",Vector2(363,y+84),16)
	text_at("このあと、主を守る場所を選びます。",Vector2(363,y+111),12,MUTED)

func draw_result() -> void:
	overlay(Rect2(215, 120, 530, 360))
	text_at("庭は守られた。" if state == "won" else "主が連れ去られた。", Vector2(258, 183), 30, GREEN if state == "won" else RED)
	text_at("生き残った生態系が、次の庭の力になる。" if state == "won" else "守り手を増やし、帰り道にも防衛を。", Vector2(258, 222), 14, MUTED)
	text_at("撃破 %d / %d    救出 %d    掘削 %d マス" % [sim.kills, sim.heroes.size(), sim.rescued, sim.dug], Vector2(258, 269), 15)
	if state == "won":
		text_at("獲得報酬  残資源 +%d / 軍 +%d / 時間 +%d" % [sim.bonus.reserve, sim.bonus.army, sim.bonus.time], Vector2(258, 308), 14, GOLD)
	else:
		text_at("広い部屋は繁殖に。細い通路は迎撃に。", Vector2(258, 308), 14, GOLD)
	text_at("1面試作のため、次ステージへの移行はありません。", Vector2(258, 353), 12, MUTED)
	draw_rect(Rect2(257, 385, 444, 47), Color("29463e"))
	text_at("A / Enter   もう一度育てる", Vector2(306, 416), 18)

func preview_scene() -> void:
	restart()
	for y in range(4, 18):
		sim.dig(Vector2i(30, y))
	for y in range(6, 16):
		for x in range(26, 35):
			sim.dig(Vector2i(x, y))
	sim.monarch = Vector2i(30, 17)
	sim.cursor = Vector2i(30, 10)
	center_camera(sim.cursor, true)
	sim.notice = "光る土を掘って、灯苔 → 琥珀虫 → 石角の生態系を育てよう。"

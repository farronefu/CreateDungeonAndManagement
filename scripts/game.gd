extends Node2D

const Sim = preload("res://scripts/simulation.gd")
const FONT = preload("res://assets/NotoSansJP.otf")
const ACTORS = preload("res://assets/actors.png")
const TILES = preload("res://assets/tiles.png")
const TILE = 24
const MAP = Rect2(24, 104, 672, 432)
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
var camera = Vector2i(16, 0)
var view_target: String = "cursor"
var lb_next_hero: bool = true
var accumulator: float = 0.0
var state_timer: float = 0.0
var animation: float = 0.0
var held_direction = Vector2i.ZERO
var repeat_timer: float = 0.0
var pause_choice: int = 0
var screenshot_mode: bool = false
var sounds: Dictionary = {}
var sound_player: AudioStreamPlayer
var particles: Array = []
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
		screenshot_mode = true
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
	camera = Vector2i(16, 0)
	view_target = "cursor"
	lb_next_hero = true
	held_direction = Vector2i.ZERO
	particles.clear()
	play_sound("confirm")

func _process(delta: float) -> void:
	if state in RUNNING_STATES:
		animation += delta
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
	if state in RUNNING_STATES:
		for particle in particles:
			particle.life -= delta
			particle.pos += particle.velocity * delta
	particles = particles.filter(func(p): return p.life > 0)
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
		if state == "prepare" and sim.elapsed >= PREP_SECONDS:
			arrive()
			break
		if not sim.outcome.is_empty():
			state = sim.outcome
			play_sound("win" if state == "won" else "alert")
			break
	if not sim.events.is_empty():
		play_sound("alert")
		sim.events.clear()
	if view_target != "cursor":
		follow_target()

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
		for i in range(5):
			particles.append({"pos": Vector2(sim.cursor * TILE + Vector2i(12, 12)), "velocity": Vector2(randf_range(-32, 32), randf_range(-45, 15)), "life": 0.3})
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

func follow_target() -> void:
	var p = target_position()
	if p.x >= 0:
		center_camera(p, true)

func center_camera(p: Vector2i, centered: bool) -> void:
	if centered:
		camera = p - Vector2i(14, 9)
	else:
		if p.x < camera.x + 3: camera.x = p.x - 3
		if p.x >= camera.x + 25: camera.x = p.x - 24
		if p.y < camera.y + 3: camera.y = p.y - 3
		if p.y >= camera.y + 15: camera.y = p.y - 14
	camera = camera.clamp(Vector2i.ZERO, Vector2i(Sim.WIDTH - 28, sim.height - 18))

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
	draw_rect(Rect2(0, 0, 960, 600), Color("0c181f"))
	draw_rect(Rect2(0, 0, 960, 3), GOLD)
	text_at("深 庭", Vector2(24, 43), 28)
	text_at("D E E P G A R D E N", Vector2(121, 40), 12, GOLD)
	text_at("01  /  根のゆりかご", Vector2(24, 77), 16, MUTED)
	var label = {"title": "生態系ダンジョン防衛", "prepare": "育成・掘削", "arrival": "侵入者接近", "placement": "主を配置 / 時間停止", "battle": "防衛中", "paused": "一時停止", "won": "防衛成功", "lost": "防衛失敗"}.get(state, "時間停止")
	text_at(label, Vector2(480, 40), 16, GREEN)
	text_at("掘削力", Vector2(724, 31), 12, MUTED)
	text_at(str(sim.power).pad_zeros(3), Vector2(722, 70), 34, GOLD)
	text_at("60 × " + str(sim.height), Vector2(846, 69), 13, MUTED)
	if state == "prepare":
		text_at("到来まで %03d 秒" % maxi(0, int(PREP_SECONDS - sim.elapsed)), Vector2(480, 75), 14, GOLD)
	elif state == "battle":
		text_at("戦闘 %03d 秒  /  救出 %d" % [int(sim.battle_elapsed), sim.rescued], Vector2(480, 75), 14, GOLD)
	text_at(sim.notice, Vector2(24, 97), 11, INK)
	draw_map()
	draw_sidebar()
	draw_rect(Rect2(24, 546, 912, 1), Color("31453f"))
	text_at("十字 移動    X 掘る・長押し連続    LB 勇者 / 主    Y 早期呼出    Menu 停止", Vector2(24, 571), 13)
	text_at("KEYBOARD   ↑↓←→ / X / Tab / Y / P    決定 Enter", Vector2(24, 591), 10, MUTED)
	text_at("PROTOTYPE  0.1", Vector2(828, 590), 10, MUTED)
	if state == "title": draw_title()
	elif state == "paused": draw_pause()
	elif state == "arrival": draw_arrival()
	elif state in ["won", "lost"]: draw_result()

func draw_map() -> void:
	draw_rect(MAP.grow(2), Color("667366"), false, 2)
	for y in range(18):
		for x in range(28):
			var p = Vector2i(x, y) + camera
			var idx = sim.index(p)
			var tier = 0
			if sim.soil[idx] == 1:
				tier = 3 if sim.nutrients[idx] >= 17 else (2 if sim.nutrients[idx] >= 10 else 1)
			draw_texture_rect_region(TILES, Rect2(MAP.position + Vector2(x, y) * TILE, Vector2(TILE, TILE)), Rect2(tier * TILE, 0, TILE, TILE))
	for p in sim.nests:
		if on_screen(p):
			draw_rect(Rect2(screen_pos(p) + Vector2(3, 15), Vector2(18, 6)), Color("605339"))
	if on_screen(sim.entrance):
		var at = screen_pos(sim.entrance)
		draw_rect(Rect2(at + Vector2(4, 0), Vector2(16, 24)), Color("b8b992"))
		for y in range(4, 24, 5):
			draw_line(at + Vector2(6, y), at + Vector2(17, y), Color("354c48"), 2)
	for a in sim.creatures:
		if not a.dead: draw_actor(a.kind, a.pos, a.hp / a.max_hp, a.flash)
	if sim.monarch.x >= 0:
		draw_actor("heart", sim.monarch, 1.0, 0.0)
		if on_screen(sim.monarch):
			draw_rect(Rect2(screen_pos(sim.monarch) + Vector2(5, 0), Vector2(14, 2)), GOLD)
	for h in sim.heroes:
		if not h.dead:
			draw_actor(h.kind, h.pos, h.hp / h.max_hp, h.flash)
			if h.id == sim.carrier and on_screen(h.pos):
				draw_arc(screen_pos(h.pos) + Vector2(12, 12), 12, 0, TAU, 20, RED, 2)
	if on_screen(sim.cursor):
		var rect = Rect2(screen_pos(sim.cursor), Vector2(TILE, TILE))
		var col = GOLD
		if state == "placement":
			col = GREEN if sim.can_place(sim.cursor) else RED
			if sim.can_place(sim.cursor): draw_actor("heart", sim.cursor, 1.0, 0.0, 0.6)
		draw_rect(rect, col, false, 2)
		draw_rect(rect.grow(2), Color(col, 0.25 + 0.15 * sin(animation * 5)), false, 1)
	for particle in particles:
		var at: Vector2 = MAP.position + particle.pos - Vector2(camera * TILE)
		if MAP.has_point(at): draw_rect(Rect2(at, Vector2(3, 3)), GOLD)
	var focus_label = {"cursor": "掘削カーソル", "hero": "侵入者を追跡", "monarch": "主を追跡"}[view_target]
	text_at("%s  %02d:%02d" % [focus_label, sim.cursor.x, sim.cursor.y], Vector2(249, 77), 11, GOLD)

func screen_pos(p: Vector2i) -> Vector2:
	return MAP.position + Vector2((p - camera) * TILE)

func on_screen(p: Vector2i) -> bool:
	return p.x >= camera.x and p.x < camera.x + 28 and p.y >= camera.y and p.y < camera.y + 18

func draw_actor(kind: String, p: Vector2i, ratio: float, flash: float, alpha: float = 1.0) -> void:
	if not on_screen(p): return
	var pos = screen_pos(p)
	var frame = int(animation * 3) % 2
	var tint = Color(1.5, 1.5, 1.5, alpha) if flash > 0 else Color(1, 1, 1, alpha)
	draw_texture_rect_region(ACTORS, Rect2(pos, Vector2(TILE, TILE)), Rect2(KINDS.find(kind) * TILE, frame * TILE, TILE, TILE), tint)
	if ratio < 0.97:
		draw_rect(Rect2(pos + Vector2(4, 23), Vector2(16, 1)), Color("263b3c"))
		draw_rect(Rect2(pos + Vector2(4, 23), Vector2(maxf(0, 16 * ratio), 1)), RED if kind in ["knight", "healer"] else GREEN)

func draw_sidebar() -> void:
	panel(Rect2(712, 104, 224, 158))
	text_at("ECOSYSTEM", Vector2(726, 126), 11, GOLD)
	var counts = sim.counts()
	var names = ["灯苔 / 生産者", "琥珀虫 / 捕食者", "石角 / 守り手"]
	for i in range(3):
		var y = 138 + i * 32
		draw_texture_rect_region(ACTORS, Rect2(722, y - 2, 24, 24), Rect2(i * 24, 0, 24, 24))
		text_at(names[i], Vector2(752, y + 15), 12)
		text_at(str(counts[KINDS[i]]).pad_zeros(2), Vector2(897, y + 15), 16, GREEN)
	text_at("軍力 %d   卵 %d" % [sim.army_power(), counts.egg], Vector2(727, 249), 12, MUTED)
	panel(Rect2(712, 272, 224, 121))
	text_at("INVADERS", Vector2(726, 294), 11, GOLD)
	if sim.heroes.is_empty():
		text_at("鉄の測量士 ＋ 灯の修道士", Vector2(726, 319), 12)
		text_at("掘って育て、通路に守りを。", Vector2(726, 345), 12, MUTED)
		text_at("準備ができたら Y で呼ぶ", Vector2(726, 375), 12, GOLD)
	else:
		for i in range(sim.heroes.size()):
			var h = sim.heroes[i]
			var y = 311 + i * 37
			text_at(("測量士" if i == 0 else "修道士") + (" / 撃破" if h.dead else (" / 運搬中" if h.id == sim.carrier else "")), Vector2(726, y), 12, RED if h.id == sim.carrier else INK)
			draw_rect(Rect2(726, y + 7, 140, 4), Color("293b40"))
			draw_rect(Rect2(726, y + 7, 140 * maxf(0, h.hp / h.max_hp), 4), RED)
			text_at(str(maxi(0, int(h.hp))), Vector2(880, y + 12), 11, MUTED)
	panel(Rect2(712, 403, 224, 133))
	text_at("地下全図", Vector2(725, 424), 11, GOLD)
	for y in range(sim.height):
		for x in range(Sim.WIDTH):
			var pos = Vector2(725 + x * 2, 434 + y * 2)
			if sim.soil[sim.index(Vector2i(x, y))] == 0:
				draw_rect(Rect2(pos, Vector2(2, 2)), Color("94ad93"))
	draw_rect(Rect2(725 + camera.x * 2, 434 + camera.y * 2, 56, 36), GOLD, false, 1)
	if sim.monarch.x >= 0: draw_rect(Rect2(Vector2(725, 434) + Vector2(sim.monarch * 2), Vector2(3, 3)), GOLD)
	for h in sim.heroes:
		if not h.dead: draw_rect(Rect2(Vector2(725, 434) + Vector2(h.pos * 2), Vector2(3, 3)), RED)
	var idx = sim.index(sim.cursor)
	text_at("選択中", Vector2(860, 446), 11, MUTED)
	text_at("養分 %d" % sim.nutrients[idx], Vector2(860, 469), 12)
	text_at("魔分 %d" % sim.mana[idx], Vector2(860, 491), 12)
	text_at("%d / %d" % [sim.cursor.y + 1, sim.height], Vector2(860, 520), 11, MUTED)

func overlay(rect: Rect2) -> void:
	draw_rect(Rect2(0, 0, 960, 600), Color(0.015, 0.035, 0.045, 0.88))
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
		draw_texture_rect_region(ACTORS, Rect2(625 + i * 50, 148, 48, 48), Rect2(i * 24, 0, 24, 24))
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
	overlay(Rect2(210, 200, 540, 180))
	text_at("侵入者が、庭の入口に。", Vector2(260, 260), 27, GOLD)
	text_at("鉄の測量士 ＋ 灯の修道士", Vector2(260, 305), 18)
	text_at("このあと、主を守る場所を選びます。", Vector2(260, 344), 14, MUTED)

func draw_result() -> void:
	overlay(Rect2(215, 120, 530, 360))
	text_at("庭は守られた。" if state == "won" else "主が連れ去られた。", Vector2(258, 183), 30, GREEN if state == "won" else RED)
	text_at("生き残った生態系が、次の庭の力になる。" if state == "won" else "守り手を増やし、帰り道にも防衛を。", Vector2(258, 222), 14, MUTED)
	text_at("撃破 %d / 2    救出 %d    掘削 %d マス" % [sim.kills, sim.rescued, sim.dug], Vector2(258, 269), 15)
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
	sim.notice = "光る土を掘って、灯苔 → 琥珀虫 → 石角の生態系を育てよう。"

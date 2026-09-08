extends SceneTree

const Game = preload("res://scripts/game.gd")
var game
var failures = 0
var capture_dir: String = ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):
			capture_dir = arg.trim_prefix("--captures=")
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures += 1

func button(code: int, pressed: bool) -> void:
	var event = InputEventJoypadButton.new()
	event.button_index = code
	event.pressed = pressed
	event.device = 0
	Input.parse_input_event(event)
	await process_frame
	await process_frame

func tap(code: int) -> void:
	await button(code, true)
	await button(code, false)

func capture(name: String) -> void:
	await process_frame
	await process_frame
	if not capture_dir.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join(name + ".png"))

func run() -> void:
	game = Game.new()
	root.add_child(game)
	await capture("title")
	await tap(JOY_BUTTON_A)
	check(game.state == "prepare", "real input dispatch A starts session")
	await tap(JOY_BUTTON_DPAD_DOWN)
	check(game.sim.cursor == Vector2i(30, 4), "real d-pad event moves exactly one tile")
	await button(JOY_BUTTON_X, true)
	await button(JOY_BUTTON_DPAD_DOWN, true)
	await create_timer(0.6).timeout
	await button(JOY_BUTTON_DPAD_DOWN, false)
	await button(JOY_BUTTON_X, false)
	check(game.sim.dug >= 4, "real held X plus held d-pad continuously digs")
	game.preview_scene()
	await create_timer(3.0).timeout
	await capture("garden")
	await tap(JOY_BUTTON_START)
	check(game.state == "paused", "Start pauses")
	var stopped = game.sim.snapshot()
	await create_timer(0.5).timeout
	check(game.sim.snapshot() == stopped, "rendered pause leaves world unchanged")
	await capture("pause")
	await tap(JOY_BUTTON_B)
	check(game.state == "prepare", "B resumes")
	await tap(JOY_BUTTON_Y)
	check(game.state == "arrival", "Y dispatch triggers arrival")
	await capture("arrival")
	await create_timer(2.3).timeout
	check(game.state == "placement", "arrival transitions to placement")
	game.sim.cursor = Vector2i(30, 16)
	await capture("placement")
	await tap(JOY_BUTTON_A)
	check(game.state == "battle", "A confirms placement and starts battle")
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	check(game.view_target == "hero", "LB dispatch tracks invader")
	await capture("battle")
	await tap(JOY_BUTTON_LEFT_SHOULDER)
	check(game.view_target == "monarch", "second LB dispatch tracks monarch")
	for h in game.sim.heroes:
		game.sim.hit_hero(h, 9999)
	await create_timer(0.3).timeout
	check(game.state == "won", "victory presentation")
	await capture("victory")
	await tap(JOY_BUTTON_A)
	check(game.state == "prepare" and game.sim.dug == 0, "A retries from clean initial world")
	game.sim.start_battle(Vector2i(30, 1), true)
	game.sim.heroes[0].pos = Vector2i(30, 1)
	game.sim.carrier = 0
	game.state = "battle"
	await create_timer(1.0).timeout
	check(game.state == "lost", "defeat presentation")
	await capture("defeat")
	print("UI RESULT failures=%d" % failures)
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)

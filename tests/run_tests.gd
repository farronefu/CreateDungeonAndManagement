extends SceneTree

const Sim = preload("res://scripts/simulation.gd")
const Game = preload("res://scripts/game.gd")
var checks: int = 0
var failures: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)
	else:
		print("PASS: " + message)

func _initialize() -> void:
	call_deferred("run")

func corridor(depth: int = 14) -> GardenSimulation:
	var s = Sim.new()
	for y in range(4, depth + 1):
		s.dig(Vector2i(30, y))
	s.creatures.clear()
	return s

func run() -> void:
	var s = Sim.new()
	check(s.soil.size() == 2400, "60x40 map")
	check(Sim.new(72).soil.size() == 4320, "60x72 map supported")
	check(s.nutrients == Sim.new().nutrients, "reproducible map seed")
	check(not s.dig(Vector2i(-1, 0)), "out-of-bounds digging rejected")
	check(not s.dig(Vector2i(0, 39)), "isolated soil rejected")
	var initial = s.power
	check(s.dig(Vector2i(30, 4)), "adjacent soil dig succeeds")
	check(s.power == initial - 1 and s.creatures.size() == 1, "dig consumes one resource and spawns")
	check(not s.dig(Vector2i(30, 4)) and s.power == initial - 1, "empty tile never consumes resource")
	s.power = 0
	check(not s.dig(Vector2i(30, 5)), "no digging at zero power")
	check(s.outcome.is_empty(), "zero power is not instant defeat")
	check(s.can_place(Vector2i(30, 4)) and not s.can_place(s.entrance), "placement uses connected tunnel excluding exit")

	s = corridor()
	var prey = s.spawn("sprout", Vector2i(30, 7), 4, 2)
	var eater = s.spawn("beetle", Vector2i(30, 7), 10)
	s.creature_action(eater, false)
	check(prey.dead and eater.food == 16, "predation transfers nutrients and magic")
	var before = s.nutrients.duplicate()
	s.remove_creature(eater)
	check(s.nutrients != before, "death returns nutrients to neighboring soil")
	s.creatures.clear()
	var sprout = s.spawn("sprout", Vector2i(30, 7), 1)
	s.creature_action(sprout, false)
	check(sprout.food > 1, "producer absorbs soil nutrients")
	s.creature_action(sprout, false)
	check(sprout.food == 1, "producer releases concentrated nutrients")
	var egg = s.spawn("egg", Vector2i(30, 10), 10)
	egg.age = 10
	s.creature_action(egg, false)
	check(egg.kind == "warden", "egg grows into defender")

	s = corridor()
	s.start_battle(Vector2i(30, 12))
	check(s.heroes.size() == 2, "two-person invasion")
	s.heroes[0].hp = 30
	s.hero_action(s.heroes[1])
	check(s.heroes[0].hp == 75 and s.heroes[1].mp == 54, "healer uses MP to heal low-HP ally")
	s.heroes[0].pos = s.monarch
	s.hero_action(s.heroes[0])
	check(s.carrier == 0, "invader captures monarch")
	s.hero_action(s.heroes[0])
	check(s.heroes[0].pos == Vector2i(30, 11) and s.monarch == s.heroes[0].pos, "carrier heads to exit along shortest path")
	var liberation = s.heroes[0].pos
	s.hit_hero(s.heroes[0], 9999)
	check(s.carrier == -1 and s.monarch == liberation and s.rescued == 1, "carrier death liberates monarch in place")
	s.heroes[1].pos = s.monarch
	s.hero_action(s.heroes[1])
	check(s.carrier == 1, "remaining invader can recapture")
	var previous_mp = s.heroes[1].mp
	s.heroes[1].hp = 10
	s.hero_action(s.heroes[1])
	check(s.heroes[1].mp == previous_mp, "carrier cannot use healing skill")
	s.hit_hero(s.heroes[1], 9999)
	s.tick(0.1, true)
	check(s.outcome == "won", "all invaders defeated gives victory")
	check(s.bonus.has("time") and s.bonus.time >= 0, "bounded nonnegative time reward")
	var reward_power = s.power
	s.tick(0.1, true)
	check(s.power == reward_power, "result reward cannot repeat")

	s = corridor()
	s.start_battle(Vector2i(30, 8), true)
	s.heroes[0].pos = s.monarch
	s.hero_action(s.heroes[0])
	for i in range(10): s.hero_action(s.heroes[0])
	check(s.outcome == "lost", "carrier reaching exit gives defeat")

	var game = Game.new()
	root.add_child(game)
	game.set_process(false)
	game.restart()
	var retained = game.sim
	for phase in ["title", "arrival", "placement", "paused", "upgrade", "transition", "won", "lost"]:
		game.state = phase
		var snapshot = game.sim.snapshot()
		for i in range(20): game.advance_time(0.1)
		check(game.sim.snapshot() == snapshot, phase + " freezes ecology, combat and timers")
	check(game.sim == retained, "frozen phases preserve same world state")
	game.state = "prepare"
	game.advance_time(0.2)
	check(game.sim.elapsed > 0, "preparation advances ecology")
	game.sim.elapsed = 150
	game.advance_time(0.1)
	check(game.state == "arrival", "preparation timeout triggers arrival")
	game.restart()
	var summon = InputEventJoypadButton.new()
	summon.button_index = JOY_BUTTON_Y
	summon.pressed = true
	game._unhandled_input(summon)
	check(game.state == "arrival", "controller Y triggers early arrival")
	game.restart()
	var dig_event = InputEventJoypadButton.new()
	dig_event.button_index = JOY_BUTTON_X
	dig_event.pressed = true
	game.sim.cursor = Vector2i(30, 4)
	game._unhandled_input(dig_event)
	check(game.sim.dug == 1, "controller X digs")
	Input.action_press("dig")
	game.move_cursor(Vector2i.DOWN)
	game.move_cursor(Vector2i.DOWN)
	Input.action_release("dig")
	check(game.sim.dug == 3 and game.sim.power == 157, "held X plus direction digs once per new tile")
	game.sim.start_battle(Vector2i(30, 6))
	var old_cursor = game.sim.cursor
	game.toggle_focus()
	check(game.view_target == "hero", "LB first selects invader")
	game.toggle_focus()
	check(game.view_target == "monarch" and old_cursor == game.sim.cursor, "LB alternates to monarch without moving cursor")
	game.sim.carrier = 1
	game.view_target = "hero"
	game.sim.heroes[1].pos = Vector2i(30, 5)
	check(game.target_position() == Vector2i(30, 5), "LB prioritizes carrier")
	game.center_camera(Vector2i(59, 39), true)
	check(game.camera == Vector2i(32, 22), "camera clamps at lower right")
	game.sim.cursor = Vector2i.ZERO
	game.move_cursor(Vector2i.LEFT)
	check(game.sim.cursor == Vector2i.ZERO, "cursor clamps to map")
	game.state = "battle"
	game.controller_changed(0, false)
	check(game.state == "paused", "controller disconnect pauses gameplay")
	game.queue_free()
	await process_frame

	# A full deterministic session checks ecology, AI and end-state integration.
	s = Sim.new()
	for y in range(4, 19): s.dig(Vector2i(30, y))
	for y in range(6, 15):
		for x in range(27, 34): s.dig(Vector2i(x, y))
	for i in range(200): s.tick(0.1, false)
	s.start_battle(Vector2i(30, 18))
	var started = Time.get_ticks_usec()
	for i in range(6000):
		s.tick(0.1, true)
		if not s.outcome.is_empty(): break
	check(not s.outcome.is_empty(), "full session reaches a result within 600 simulated seconds")
	check(s.creatures.all(func(a): return s.open_at(a.pos)), "all surviving creatures remain in tunnels")
	print("SESSION outcome=%s creatures=%d battle_seconds=%.1f cpu_ms=%.2f" % [s.outcome, s.creatures.size(), s.battle_elapsed, (Time.get_ticks_usec() - started) / 1000.0])
	print("RESULT %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

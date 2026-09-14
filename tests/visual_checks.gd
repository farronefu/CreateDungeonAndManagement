extends SceneTree
const Game = preload("res://scripts/game.gd")
var failures = 0
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var g = Game.new()
	g.muted = true
	root.add_child(g)
	g.set_process(false)
	g.restart()
	check(g.presentation.art.entries.has("sprout") and g.presentation.art.entries.has("knight"),"user art catalog loads")
	check(g.presentation.art.textures.knight.get_size() == Vector2(1536,1024),"hero sheet size preserved")
	var a = g.sim.spawn("sprout",Vector2i(30,2),5)
	g.visuals.observe(g.sim)
	var id = g.visuals.key(a)
	a.pos = Vector2i(30,3)
	g.visuals.observe(g.sim)
	g.visuals.update(0.09)
	check(is_equal_approx(g.visuals.position(id,Vector2.ZERO).y,2.5),"movement interpolates between cells")
	g.visuals.update(0.2)
	check(g.visuals.position(id,Vector2.ZERO) == Vector2(30,3),"movement settles at simulation cell")
	g.sim.visual("attack",a.pos,id,Vector2.UP)
	g.visuals.observe(g.sim)
	check(g.visuals.poses[id].direction == Vector2.UP,"attack pose retains vertical direction")
	var saved = g.sim.snapshot()
	g.visuals.update(0.4)
	check(saved == g.sim.snapshot(),"presentation never advances world or RNG")
	g.visuals.emit("dig",Vector2(30,3))
	var time = g.visuals.clock
	g.state = "paused"
	g._process(0.5)
	check(g.visuals.clock == time,"pause freezes effects")
	g.state = "upgrade"
	g._process(0.5)
	check(g.visuals.clock == time and saved == g.sim.snapshot(),"upgrade freezes effects and simulation")
	g.state = "transition"
	g._process(0.5)
	check(g.visuals.clock == time and saved == g.sim.snapshot(),"transition freezes effects and simulation")
	g.sim.visual_events.clear()
	g.sim.hit_creature(a,999)
	check(g.sim.visual_events.any(func(e):return e.type=="death"),"actual death emits effect")
	for i in range(300): g.sim.visual("hit",Vector2i.ZERO)
	check(g.sim.visual_events.size()<=128,"headless event queue stays bounded")
	for i in range(200): g.visuals.emit("hit",Vector2.ZERO)
	check(g.visuals.effects.size()<=96,"crowd effect count stays bounded")
	g.visuals.reset()
	check(g.visuals.poses.is_empty() and g.visuals.effects.is_empty(),"restart clears presentation")
	g.queue_free()
	await process_frame
	print("VISUAL RESULT 13 checks failures=%d"%failures)
	quit(1 if failures else 0)

extends SceneTree
const Game = preload("res://scripts/game.gd")
var g
var folder = "res://docs/images/v04/"
func _initialize() -> void:
	call_deferred("run")
func capture(name: String) -> void:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(folder+name+".png")
func run() -> void:
	g = Game.new()
	g.muted = true
	root.add_child(g)
	g.set_process(false)
	g.restart()
	for y in range(4,10):
		for x in range(28,34):
			g.sim.soil[g.sim.index(Vector2i(x,y))] = 0
	g.camera=Vector2i(18,0)
	g.sim.creatures.clear()
	g.sim.visual_events.clear()
	var a=g.sim.spawn("sprout",Vector2i(30,6),5)
	g.visuals.observe(g.sim)
	g.visuals.update(0.14)
	await capture("quality-birth")
	g.visuals.update(1)
	a.pos=Vector2i(31,6)
	g.visuals.observe(g.sim)
	g.visuals.update(0.09)
	await capture("quality-move")
	g.sim.cursor=Vector2i(34,7)
	g.try_dig()
	await capture("quality-dig-start")
	g.visuals.update(0.08)
	await capture("quality-dig")
	g.visuals.update(0.12)
	await capture("quality-dig-end")
	g.sim.start_battle(Vector2i(30,9),true)
	g.sim.heroes[0].pos=Vector2i(31,7)
	g.state="battle"
	g.visuals.observe(g.sim)
	g.sim.heroes[0].motion_left=0
	g.sim.hero_action(g.sim.heroes[0])
	g.advance_time(0.3)
	g.visuals.observe(g.sim)
	g.visuals.update(0.06)
	await capture("quality-hit")
	g.sim.hit_hero(g.sim.heroes[0],999)
	g.advance_time(0.1)
	g.visuals.update(0.1)
	await capture("quality-death")
	g._process(2)
	await capture("quality-result")
	print("QUALITY captures complete")
	g.queue_free()
	await process_frame
	quit()

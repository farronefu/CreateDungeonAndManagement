extends SceneTree
const Game = preload("res://scripts/game.gd")
var g
var folder = "res://docs/images/v04/"
var sheet: Image
var index = 0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="): folder=arg.trim_prefix("--captures=").trim_suffix("/")+"/"
	call_deferred("run")
func capture(name: String, full: bool = false):
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var im = root.get_texture().get_image()
	if full: im.save_png(folder+name+".png")
	var at = g.screen_pos(Vector2i(30,5))
	var crop=im.get_region(Rect2i(Vector2i(at)-Vector2i(28,28),Vector2i(96,96)))
	crop.resize(192,192,Image.INTERPOLATE_NEAREST)
	sheet.blit_rect(crop,Rect2i(0,0,192,192),Vector2i(index%6,index/6)*192)
	index+=1
func run():
	g=Game.new()
	g.muted=true
	root.add_child(g)
	g.set_process(false)
	g.restart()
	for y in range(0,10):
		for x in range(28,34): g.sim.soil[g.sim.index(Vector2i(x,y))]=0
	g.sim.creatures.clear()
	g.sim.visual_events.clear()
	g.sim.start_battle(Vector2i(30,8))
	g.state="battle"
	var h=g.sim.heroes[0]
	h.pos=Vector2i(30,5)
	g.visuals.observe(g.sim)
	sheet=Image.create(1152,576,false,Image.FORMAT_RGBA8)
	sheet.fill(Color("252d30"))
	for d in [Vector2i.DOWN,Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:
		h.heading=d
		h.motion="move"
		h.motion_time=0.12
		h.motion_left=0.13
		await capture("move")
	for time in [0.2,0.4]:
		h.motion="look"
		h.motion_time=time
		await capture("look")
	for d in [Vector2i.DOWN,Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:
		h.heading=d
		h.motion="attack"
		h.motion_time=0.32
		await capture("attack_"+str(d),true)
	for time in [0.3,0.65]:
		h.motion="celebrate"
		h.motion_time=time
		await capture("celebrate",time>0.6)
	g.sim.hit_hero(h,999)
	g.visuals.observe(g.sim)
	g.visuals.effects.clear() # Atlas review isolates pose shapes; effects have separate captures.
	for time in [0.0,0.3,0.6,0.8,0.9,1.1]:
		g.visuals.poses.h0.death_age=time
		await capture("bones" if time>=0.9 else "death",time==0.6 or time==0.9)
	sheet.save_png(folder+"motions-contact.png")
	print("HERO captures complete: 4 move, 2 look, 4 attacks, 2 celebration, 6 death/bones")
	g.queue_free()
	await process_frame
	quit()

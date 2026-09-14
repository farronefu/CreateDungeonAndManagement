extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Game = preload("res://scripts/game.gd")
var checks = 0
var failures = 0
func check(ok: bool, message: String) -> void:
	checks+=1
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures+=1
func room():
	var s=Sim.new()
	for y in range(0,15): s.soil[s.index(Vector2i(30,y))]=0
	for x in range(28,33): s.soil[s.index(Vector2i(x,5))]=0
	s.start_battle(Vector2i(30,12))
	return s
func ticks(s, count: int):
	for i in range(count): s.tick(0.1,true)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var s=room()
	var h=s.heroes[0]
	check(s.heroes.size()==1 and h.kind=="knight","single warrior invasion by default")
	check(h.motion=="celebrate","entry starts celebration")
	ticks(s,5)
	check(h.pos==s.entrance,"entry celebration holds position")
	ticks(s,4)
	check(h.pos!=s.entrance,"entry celebration completes and movement starts")
	h.pos=Vector2i(30,5)
	h.previous=Vector2i(30,4)
	h.motion_left=0
	s.hero_action(h)
	check(h.motion=="look" and h.pos==Vector2i(30,5),"junction starts stationary look")
	ticks(s,4)
	check(h.pos==Vector2i(30,5),"look holds for its duration")
	ticks(s,4)
	check(h.pos!=Vector2i(30,5),"junction resumes movement after one look")
	h.pos=s.monarch
	h.motion_left=0
	s.hero_action(h)
	check(s.carrier==h.id and h.motion=="celebrate","capture celebrates")
	var captured=h.pos
	ticks(s,4)
	check(h.pos==captured,"capture celebration holds position")
	ticks(s,5)
	check(h.pos.y<captured.y,"carrier exits after celebration")
	h.pos=Vector2i(30,5)
	h.motion_left=0
	s.hero_action(h)
	check(h.pos==Vector2i(30,4) and h.motion=="move","carrier skips junction look")
	for direction in Sim.DIRS:
		s=room()
		h=s.heroes[0]
		h.pos=Vector2i(30,5)
		h.motion_left=0
		var a=s.spawn("egg",h.pos+direction,1)
		a.cooldown=100
		var hp=a.hp
		s.hero_action(h)
		check(h.motion=="attack" and h.heading==direction,"directional attack "+str(direction))
		check(a.hp==hp,"damage waits for sword contact")
		check(not s.visual_events.any(func(e):return e.type=="attack"),"slash waits for sword contact")
		ticks(s,3)
		check(a.hp<hp,"contact applies damage")
		check(s.visual_events.any(func(e):return e.type=="attack"),"contact emits slash")
	var g=Game.new()
	g.muted=true
	root.add_child(g)
	g.set_process(false)
	g.sim=room()
	g.state="battle"
	g.visuals.observe(g.sim)
	g.sim.hit_hero(g.sim.heroes[0],999)
	g.advance_time(0.1)
	check(g.state=="won" and g.visuals.poses.h0.has("death_age"),"dead hero remains in presentation")
	g._process(0.9)
	check(g.visuals.poses.h0.death_age>=0.85 and g.result_elapsed<Game.RESULT_DELAY,"bones appear before results")
	var snapshot=g.sim.snapshot()
	g._process(1.0)
	check(snapshot==g.sim.snapshot(),"death and result animation leave world frozen")
	g.restart()
	g.sim=room()
	g.state="battle"
	g.advance_time(0.2)
	g.state="paused"
	snapshot=g.sim.snapshot()
	g._process(1.0)
	check(snapshot==g.sim.snapshot(),"pause freezes hero animation state")
	var clips=g.presentation.art.entries.knight.animations
	var art=g.presentation.art
	check(clips.look.placeholder and clips.death.placeholder and clips.celebrate.placeholder,"unfinished poses are explicitly temporary")
	check(art.textures.knight.get_size()==Vector2(320,160),"new blue hero walk sheet loaded")
	check(art.clip_textures[clips.portrait.texture].get_size()==Vector2(1254,1254),"new hero portrait loaded")
	check(clips.attack_down.row==0 and clips.attack_up.row==1 and clips.attack_left.row==2 and clips.attack_right.row==3,"temporary attacks face correct directions")
	check(clips.move_down.frames==8 and clips.move_up.frames==8 and clips.move_left.frames==8 and clips.move_right.frames==8,"all four walks retain eight frames")
	check(is_equal_approx(art.scale_for("knight","attack_down"),art.scale_for("knight","move_down")),"temporary attack preserves body scale")
	check(is_equal_approx(art.scale_for("knight","move_down")*34,42.5),"new hero stays slightly taller than 40px tile")

	g.restart()
	g.sim=room()
	g.state="battle"
	var walking=g.sim.heroes[0]
	walking.motion_left=0
	g.visuals.observe(g.sim)
	g.sim.move_hero(walking,Vector2i(30,1))
	g.visuals.observe(g.sim)
	g.visuals.update(0.5)
	check(is_equal_approx(g.visuals.position("h0",Vector2.ZERO).y,0.5),"hero travels half a cell in half a second")
	g.visuals.update(0.5)
	check(g.visuals.position("h0",Vector2.ZERO)==Vector2(30,1),"hero completes cell travel in one second")
	check(clips.move_down.frames/float(clips.move_down.fps)==Sim.HERO_WALK_SECONDS,"one walk cycle matches one cell")
	for target in ["hero","monarch"]:
		g.view_target=target
		g.camera=Vector2i(3,9)
		var camera_before=g.camera
		g.advance_time(0.2)
		check(g.camera==camera_before,"world updates do not track "+target)
	g.lb_next_hero=true
	g.toggle_focus()
	check(g.camera==Vector2i(18,0),"LB still jumps to hero on request")
	g.queue_free()
	await process_frame
	print("HERO RESULT %d checks %d failures"%[checks,failures])
	quit(1 if failures else 0)

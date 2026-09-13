extends RefCounted
## All time here is presentation time, independent of simulation RNG and stats.
var poses: Dictionary = {}
var effects: Array = []
var clock: float = 0
var dig_kick: float = 0

func reset() -> void:
	poses.clear()
	effects.clear()
	clock = 0
	dig_kick = 0

func key(a: Dictionary, hero: bool = false) -> String:
	return ("h" if hero else "m") + str(a.id)

func observe(sim) -> void:
	var alive: Dictionary = {}
	for group in [sim.creatures, sim.heroes]:
		for a in group:
			if a.dead and group != sim.heroes: continue
			var id = key(a, group == sim.heroes)
			alive[id] = true
			var target = Vector2(a.pos)
			if not poses.has(id):
				poses[id] = {"from":target,"to":target,"elapsed":1.0,"face":1,"action":"idle","until":0.0}
			var pose = poses[id]
			pose.move_duration = sim.HERO_WALK_SECONDS if group == sim.heroes else 0.18
			pose.linear_walk = group == sim.heroes
			if group == sim.heroes: pose.last_tick_clock = clock
			if a.dead and not pose.has("death_age"):
				pose.death_age = 0.0
				pose.from = target
				pose.to = target
			if pose.to != target:
				pose.from = position(id, target)
				pose.elapsed = 0.0
				if target.x != pose.to.x: pose.face = 1 if target.x > pose.to.x else -1
				pose.to = target
	for id in poses.keys():
		if not alive.has(id): poses.erase(id)
	for event in sim.visual_events:
		emit(event.type, Vector2(event.pos), event.get("direction", Vector2.ZERO))
		var id = event.get("actor", "")
		if poses.has(id):
			poses[id].action = event.type
			poses[id].direction = Vector2(event.get("direction",Vector2.ZERO)).normalized()
			poses[id].until = clock + 0.32
			if event.get("direction", Vector2.ZERO).x != 0:
				poses[id].face = 1 if event.direction.x > 0 else -1
	sim.visual_events.clear()

func position(id: String, fallback: Vector2) -> Vector2:
	if not poses.has(id): return fallback
	var pose = poses[id]
	var t = clampf(pose.elapsed / float(pose.get("move_duration",0.18)), 0, 1)
	return pose.from.lerp(pose.to, t if pose.get("linear_walk",false) else t * t * (3 - 2 * t))

func emit(type: String, pos: Vector2, direction: Vector2 = Vector2.ZERO) -> void:
	if effects.size() >= 96: effects.pop_front()
	effects.append({"type":type,"pos":pos,"direction":direction,"age":0.0,"duration":0.7 if type in ["birth","death","hero_death"] else 0.36})
	if type == "dig": dig_kick = 0.22

func update(dt: float) -> void:
	clock += dt
	dig_kick = maxf(0, dig_kick - dt)
	for pose in poses.values():
		pose.elapsed += dt
		if pose.has("death_age"): pose.death_age += dt
	for effect in effects: effect.age += dt
	effects = effects.filter(func(e): return e.age < e.duration)

func draw(g) -> void:
	for e in effects:
		var at: Vector2 = g.MAP.position + (e.pos - Vector2(g.camera)) * g.TILE + Vector2(20, 22)
		var t: float = e.age / e.duration
		if not g.MAP.grow(-18).has_point(at): continue
		var color = Color("ddc590")
		if e.type in ["birth", "eat", "heal"]: color = Color("b5ec80")
		if e.type in ["hit", "hero_death"]: color = Color("ffe0b0")
		color.a = 1 - t
		if e.type == "attack":
			var d: Vector2 = e.direction.normalized()
			if d == Vector2.ZERO: d = Vector2.RIGHT
			var side = Vector2(-d.y, d.x)
			var tip = at + d * (12 + 12 * t)
			g.draw_polyline(PackedVector2Array([(tip-side*10-d*8).round(), tip.round(), (tip+side*8-d*4).round()]), color, 2)
		elif e.type in ["hit", "hero_death"]:
			for d in [Vector2(1,1),Vector2(-1,1),Vector2(1,-1),Vector2(-1,-1)]:
				g.draw_line((at+d*(3+8*t)).round(),(at+d*(8+9*t)).round(),color,2)
		else:
			for i in range(8):
				var angle = i * TAU / 8
				var offset = Vector2(cos(angle),sin(angle)) * (4 + 17*t)
				if e.type == "dig": offset.y += 28*t*t-12*t
				else: offset.y -= 12*t
				var p = (at + offset).round()
				if g.MAP.grow(-4).has_point(p):
					g.draw_rect(Rect2(p,Vector2(4,4) if e.type == "dig" else Vector2(2,2)),color)
		if e.type == "birth":
			g.text_at("誕生", at+Vector2(-12,-15-14*t), 10, color)

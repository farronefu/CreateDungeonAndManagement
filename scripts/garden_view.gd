extends RefCounted
## Presentation only: no changes to the simulation or its random sequence.

const SURFACE = preload("res://assets/surface-v2.png")
const TERRAIN = preload("res://assets/terrain-v2.png")
const ACTORS = preload("res://assets/actors-v2.png")
const Art = preload("res://scripts/character_art.gd")
var art = Art.new()
const CELL = 20
const KINDS = ["sprout", "beetle", "warden", "knight", "healer", "heart", "egg"]

func render(g) -> void:
	g.draw_rect(Rect2(0, 0, 960, 600), Color("171d20"))
	draw_surface(g)
	draw_dungeon(g)
	draw_hud(g)

func plate(g, rect: Rect2) -> void:
	g.draw_rect(rect, Color("20292b"))
	g.draw_rect(rect.grow(-1), Color("625743"), false, 1)
	g.draw_line(rect.position + Vector2(3, 2), rect.position + Vector2(rect.size.x - 3, 2), Color("a18c5b"), 1)

func draw_surface(g) -> void:
	# Landscape is a visual-only strip. Tiles and placement start below it.
	var size = SURFACE.get_size()
	var source_height = size.x * 136.0 / 960.0
	g.draw_texture_rect_region(SURFACE, Rect2(0, 0, 960, 136), Rect2(0, size.y - source_height, size.x, source_height))
	g.draw_rect(Rect2(0, 128, 960, 8), Color("483e2b"))
	g.draw_rect(Rect2(0, 127, 960, 3), Color("5d713b"))
	for x in range(0, 960, 6):
		var h = 2 + posmod(x * 13, 5)
		g.draw_rect(Rect2(x, 127 - h, 2, h), Color("a1a252") if x % 3 == 0 else Color("75834a"))
	var gate_x = (g.sim.entrance.x - g.camera.x) * g.TILE + g.TILE / 2
	if gate_x > -40 and gate_x < 1000:
		# Separate foreground entrance follows the true underground exit column.
		g.draw_colored_polygon(PackedVector2Array([Vector2(gate_x-40,136),Vector2(gate_x-31,100),Vector2(gate_x-18,84),Vector2(gate_x+11,80),Vector2(gate_x+32,103),Vector2(gate_x+40,136)]), Color("343e3b"))
		for y in range(94, 136, 10):
			g.draw_rect(Rect2(gate_x-32, y, 14, 8), Color("7a7b64"))
			g.draw_rect(Rect2(gate_x+18, y, 14, 8), Color("555e51"))
		g.draw_rect(Rect2(gate_x-23, 86, 39, 10), Color("9a9574"))
		g.draw_rect(Rect2(gate_x-20, 100, 40, 36), Color("161b1d"))
		g.draw_rect(Rect2(gate_x-12, 96, 24, 8), Color("161b1d"))
		g.draw_rect(Rect2(gate_x-35, 101, 8, 3), Color("75904c"))
		g.draw_rect(Rect2(gate_x+19, 114, 15, 3), Color("6e8244"))
		if g.state == "arrival":
			for i in range(1):
				var walk_x = lerpf(gate_x - 180 - i * 48, gate_x - 20, minf(1, g.state_timer / 2.2))
				art.draw(g, "knight", Vector2(walk_x+20,131),g.state_timer,"move_right")
	if g.sim.heroes.is_empty():
		plate(g, Rect2(12, 10, 250, 38))
		g.text_at("深庭", Vector2(23, 36), 21, g.GOLD)
		g.text_at("第一層  根のゆりかご", Vector2(89, 34), 13)
	else:
		for i in range(g.sim.heroes.size()):
			var h = g.sim.heroes[i]
			var x = 12 + i * 241
			plate(g, Rect2(x, 10, 231, 45))
			art.icon(g, h.kind, Vector2(x+22,48))
			var name = "測量士" if h.kind == "knight" else "修道士"
			name += "  撃破" if h.dead else ("  運搬中" if h.id == g.sim.carrier else "")
			g.text_at(name, Vector2(x+42, 29), 12, g.RED if h.id == g.sim.carrier else g.INK)
			g.draw_rect(Rect2(x+43, 37, 119, 5), Color("151b1c"))
			g.draw_rect(Rect2(x+43, 37, floorf(119*clampf(h.hp/h.max_hp,0,1)), 5), g.RED)
			g.text_at(str(maxi(0, int(h.hp))), Vector2(x+175, 43), 12, g.GOLD)
	plate(g, Rect2(730, 10, 218, 38))
	var label = ""
	match g.state:
		"prepare": label = "到来まで %03d 秒   Y 早期呼出" % maxi(0,int(g.PREP_SECONDS-g.sim.elapsed))
		"battle": label = "防衛中 %03d 秒   LB 追跡" % int(g.sim.battle_elapsed)
		"placement": label = "主を配置   A 決定 / 時間停止"
		"arrival": label = "侵入者が接近中…"
		"paused": label = "一時停止"
		"won": label = "防衛成功"
		"lost": label = "防衛失敗"
		_: label = "生態系ダンジョン防衛"
	g.text_at(label, Vector2(742, 34), 12, g.GOLD)

func draw_dungeon(g) -> void:
	for y in range(g.VISIBLE.y):
		for x in range(g.VISIBLE.x):
			var p = Vector2i(x, y) + g.camera
			var idx = g.sim.index(p)
			var tier = 0
			if g.sim.soil[idx] == 1:
				tier = 3 if g.sim.nutrients[idx] >= 17 else (2 if g.sim.nutrients[idx] >= 10 else 1)
				if g.sim.mana[idx] >= 3: tier = 4
			var variant = posmod(p.x * 13 + p.y * 7, 4)
			g.draw_texture_rect_region(TERRAIN, Rect2(g.screen_pos(p), Vector2(g.TILE,g.TILE)), Rect2(variant*CELL, tier*CELL, CELL,CELL))
			if tier == 0:
				draw_wall_shadows(g, p)
			elif p.y < 2 and (p.x % 4 == 0):
				var at = g.screen_pos(p)
				g.draw_polyline(PackedVector2Array([at+Vector2(11,0),at+Vector2(13,8),at+Vector2(9,14),at+Vector2(11,21)]),Color("4b4130"),2)
	for p in g.sim.nests:
		if g.on_screen(p):
			var at = g.screen_pos(p)
			for i in range(3):
				g.draw_rect(Rect2(at+Vector2(4+i*3,29-i*3),Vector2(31-i*6,3)),Color("8d7546"))
	if g.on_screen(g.sim.entrance):
		var at = g.screen_pos(g.sim.entrance)
		g.draw_rect(Rect2(at+Vector2(8,0),Vector2(24,40)),Color("4a4536"))
		for y in range(3,40,7):
			g.draw_rect(Rect2(at+Vector2(9,y),Vector2(22,3)),Color("a3926e"))
	for a in g.sim.creatures:
		if not a.dead:
			draw_actor(g,a.kind,a.pos,a.hp/a.max_hp,a.flash,1,g.visuals.key(a))
	if g.sim.monarch.x >= 0:
		var carry_key = "h"+str(g.sim.carrier) if g.sim.carrier>=0 else ""
		draw_actor(g,"heart",g.sim.monarch,1,0,1,carry_key)
		if g.on_screen(g.sim.monarch):
			var world = g.visuals.position(carry_key,Vector2(g.sim.monarch))
			g.draw_rect(Rect2(g.MAP.position+(world-Vector2(g.camera))*g.TILE+Vector2(14,1),Vector2(12,2)),g.GOLD)
	for h in g.sim.heroes:
		if h.dead:
			draw_hero_remains(g,h)
		else:
			draw_actor(g,h.kind,h.pos,h.hp/h.max_hp,h.flash,1,g.visuals.key(h,true),h)
			if g.on_screen(h.pos):
				var world = g.visuals.position(g.visuals.key(h,true),Vector2(h.pos))
				var at = (g.MAP.position+(world-Vector2(g.camera))*g.TILE).round()
				var direction = "up" if h.heading.y<0 else ("left" if h.heading.x<0 else ("right" if h.heading.x>0 else "down"))
				var motion = h.motion+"_"+direction if h.motion in ["move","attack"] else h.motion
				var pose = g.visuals.poses.get(g.visuals.key(h,true),{})
				var clock = h.motion_time+clampf(g.visuals.clock-float(pose.get("last_tick_clock",g.visuals.clock)),0,0.1)
				var marker_y = 1 - 32 * maxf(0,art.scale_for(h.kind,motion,clock)-1)
				g.draw_colored_polygon(PackedVector2Array([at+Vector2(15,marker_y),at+Vector2(25,marker_y),at+Vector2(20,marker_y+5)]),g.RED)
				if h.id == g.sim.carrier:
					g.draw_rect(Rect2(at+Vector2(1,1),Vector2(38,38)),g.RED,false,2)
	if g.on_screen(g.sim.cursor):
		var at = g.screen_pos(g.sim.cursor)
		var col = g.GOLD
		if g.state == "placement":
			col = g.GREEN if g.sim.can_place(g.sim.cursor) else g.RED
			if g.sim.can_place(g.sim.cursor): draw_actor(g,"heart",g.sim.cursor,1,0,0.55)
		for corner in [Vector2(1,1),Vector2(38,1),Vector2(1,38),Vector2(38,38)]:
			var dx = 8 if corner.x < 20 else -8
			var dy = 8 if corner.y < 20 else -8
			g.draw_line(at+corner,at+corner+Vector2(dx,0),col,2)
			g.draw_line(at+corner,at+corner+Vector2(0,dy),col,2)
		if g.state != "placement":
			at += Vector2(2,-3) if g.visuals.dig_kick > 0.12 else Vector2.ZERO
			g.draw_line(at+Vector2(14,29),at+Vector2(26,13),Color("392d29"),6)
			g.draw_line(at+Vector2(14,29),at+Vector2(26,13),Color("ca9360"),2)
			g.draw_polyline(PackedVector2Array([at+Vector2(14,12),at+Vector2(21,9),at+Vector2(28,12),at+Vector2(32,18)]),Color("1e252a"),6)
			g.draw_polyline(PackedVector2Array([at+Vector2(14,11),at+Vector2(21,8),at+Vector2(28,11),at+Vector2(32,17)]),Color("e0e9d5"),3)
	g.visuals.draw(g)
	for particle in g.particles:
		var at: Vector2 = g.MAP.position + particle.pos - Vector2(g.camera*g.TILE)
		if g.MAP.has_point(at): g.draw_rect(Rect2(at,Vector2(3,3)),g.GOLD)
	g.draw_line(Vector2(0,136),Vector2(960,136),Color("1b211f"),2)

func draw_wall_shadows(g, p: Vector2i) -> void:
	var at = g.screen_pos(p)
	if not g.sim.open_at(p+Vector2i.UP):
		g.draw_rect(Rect2(at,Vector2(40,7)),Color("121619"))
		g.draw_rect(Rect2(at+Vector2(0,7),Vector2(40,3)),Color(0.03,0.04,0.05,0.35))
	if not g.sim.open_at(p+Vector2i.LEFT):
		g.draw_rect(Rect2(at,Vector2(5,40)),Color("171b1e"))
	if not g.sim.open_at(p+Vector2i.RIGHT):
		g.draw_rect(Rect2(at+Vector2(37,0),Vector2(3,40)),Color("161b1d"))
	if not g.sim.open_at(p+Vector2i.DOWN):
		g.draw_rect(Rect2(at+Vector2(0,38),Vector2(40,2)),Color("5e5340"))

func draw_actor(g, kind: String, p: Vector2i, ratio: float, flash: float, alpha: float = 1, id: String = "", hero: Dictionary = {}) -> void:
	var world: Vector2 = g.visuals.position(id, Vector2(p))
	if not g.on_screen(Vector2i(world.round())): return
	var at: Vector2 = (g.MAP.position + (world-Vector2(g.camera))*g.TILE).round()
	var pose: Dictionary = g.visuals.poses.get(id,{})
	var moving = float(pose.get("elapsed",1)) < 0.18
	var action = "move" if moving else "idle"
	var bob: float = -2 if moving and sin(float(pose.elapsed)/0.18*PI)>0.4 else 0
	if float(pose.get("until",0)) > g.visuals.clock:
		action = str(pose.action)
		if action == "attack": at += Vector2(pose.get("direction",Vector2.ZERO)) * 3
	var clip_clock: float = g.animation
	if not hero.is_empty():
		var direction = "down"
		if hero.heading.x < 0: direction = "left"
		elif hero.heading.x > 0: direction = "right"
		elif hero.heading.y < 0: direction = "up"
		action = hero.motion
		clip_clock = hero.motion_time + clampf(g.visuals.clock-float(pose.get("last_tick_clock",g.visuals.clock)),0,0.1)
		if action in ["move","attack"]: action += "_" + direction
		if hero.motion == "move" and hero.motion_left <= 0: clip_clock = 0
		bob = 0
	var tint = Color(1.8,1.5,1.3,alpha) if flash>0 else Color(1,1,1,alpha)
	g.draw_rect(Rect2(at+Vector2(8,33),Vector2(24,4)),Color(0.02,0.03,0.04,0.45*alpha))
	art.draw(g,kind,at+Vector2(20,36),clip_clock,action,int(pose.get("face",1)),tint,bob)
	if ratio < 0.97:
		g.draw_rect(Rect2(at+Vector2(7,37),Vector2(26,2)),Color("162020"))
		g.draw_rect(Rect2(at+Vector2(7,37),Vector2(floorf(26*clampf(ratio,0,1)),2)),g.RED if kind in ["knight","healer"] else g.GREEN)

func draw_hud(g) -> void:
	g.draw_rect(Rect2(0,536,960,64),Color("20272a"))
	g.draw_line(Vector2(0,536),Vector2(960,536),Color("a49065"),2)
	g.draw_line(Vector2(0,578),Vector2(960,578),Color("48504a"),1)
	g.text_at("掘",Vector2(13,568),26,g.GOLD)
	g.text_at(str(g.sim.power).pad_zeros(3),Vector2(52,568),28,g.INK)
	g.text_at("軍",Vector2(134,568),26,g.GOLD)
	g.text_at(str(g.sim.army_power()).pad_zeros(3),Vector2(173,568),28,g.INK)
	var counts = g.sim.counts()
	for i in range(3):
		var x = 274+i*63
		art.icon(g,KINDS[i],Vector2(x+14,570))
		g.text_at(str(counts[KINDS[i]]),Vector2(x+31,567),15,g.GREEN)
	var idx = g.sim.index(g.sim.cursor)
	g.text_at("養分 %02d  魔分 %02d" % [g.sim.nutrients[idx],g.sim.mana[idx]],Vector2(486,563),13)
	var focus = {"cursor":"掘削", "hero":"勇者", "monarch":"魔王"}[g.view_target]
	g.text_at("%s  %02d:%02d" % [focus,g.sim.cursor.x,g.sim.cursor.y],Vector2(657,563),13,g.GOLD)
	g.text_at("地下 %02d–%02d / %02d" % [g.camera.y+1,g.camera.y+g.VISIBLE.y,g.sim.height],Vector2(798,563),12,g.MUTED)
	var hint = "十字 移動   X 掘る・長押し連続   LB 勇者 / 魔王   Y 早期呼出   Menu 停止"
	if g.state == "placement":
		hint = "十字 配置場所を選ぶ   A 配置して防衛開始   入口につながる通路へ配置できます（時間停止中）"
	elif g.state == "battle" and g.sim.carrier >= 0:
		hint = "捕縛！ LB で追跡。出口に到達する前に、運搬している勇者を倒して救出しよう。"
	elif g.sim.power <= 0:
		hint = "掘削力が尽きました。魔物の防衛を見守ろう。  LB 追跡   Menu 停止"
	g.text_at(hint,Vector2(14,594),11,g.INK)

func draw_hero_remains(g, h: Dictionary) -> void:
	if not g.on_screen(h.pos): return
	var at = g.screen_pos(h.pos)
	var age: float = g.visuals.poses.get(g.visuals.key(h,true),{}).get("death_age",0.0)
	if age < 0.85:
		art.draw(g,h.kind,at+Vector2(20,36),age,"death")
	elif art.entries.get(h.kind,{}).get("animations",{}).has("bones"):
		art.draw(g,h.kind,at+Vector2(20,36),0,"bones")
	else:
		# Temporary skull/bones, replaceable through the catalog's bones clip.
		g.draw_line(at+Vector2(12,29),at+Vector2(27,34),Color("a09b83"),2)
		g.draw_line(at+Vector2(12,34),at+Vector2(27,29),Color("d2cfb3"),2)
		g.draw_rect(Rect2(at+Vector2(17,23),Vector2(8,7)),Color("ddd9bc"))
		g.draw_rect(Rect2(at+Vector2(18,29),Vector2(6,2)),Color("b6b29a"))
		g.draw_rect(Rect2(at+Vector2(18,25),Vector2(2,2)),Color("34383a"))
		g.draw_rect(Rect2(at+Vector2(22,25),Vector2(2,2)),Color("34383a"))

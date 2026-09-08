class_name GardenSimulation
extends RefCounted

const WIDTH = 60
const MAX_HEIGHT = 72
const STEP = 0.1
const MAX_CREATURES = 220
const STATS = {
	"sprout": {"hp": 24.0, "attack": 3.0, "period": 0.8, "power": 1},
	"beetle": {"hp": 64.0, "attack": 12.0, "period": 0.6, "power": 30},
	"warden": {"hp": 165.0, "attack": 26.0, "period": 0.7, "power": 75},
	"egg": {"hp": 20.0, "attack": 0.0, "period": 1.0, "power": 0},
}
const DIRS = [Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP]
var height: int = 40
var soil = PackedByteArray()
var nutrients = PackedInt32Array()
var mana = PackedInt32Array()
var creatures: Array = []
var heroes: Array = []
var rng = RandomNumberGenerator.new()
var entrance = Vector2i(30, 0)
var cursor = Vector2i(30, 3)
var monarch = Vector2i(-1, -1)
var carrier: int = -1
var power: int = 160
var elapsed: float = 0.0
var battle_elapsed: float = 0.0
var next_id: int = 1
var outcome: String = ""
var rescued: int = 0
var kills: int = 0
var dug: int = 0
var notice: String = "養分のある土を掘って、生き物を育てよう。"
var events: Array = []
var nests: Array = []
var bonus: Dictionary = {}
var upgraded: Dictionary = {}

func _init(map_height: int = 40, seed_value: int = 240908) -> void:
	height = clampi(map_height, 40, MAX_HEIGHT)
	rng.seed = seed_value
	soil.resize(WIDTH * height)
	nutrients.resize(WIDTH * height)
	mana.resize(WIDTH * height)
	for y in range(height):
		for x in range(WIDTH):
			var i = index(Vector2i(x, y))
			soil[i] = 1
			nutrients[i] = rng.randi_range(0, 3)
			if rng.randf() < 0.11:
				nutrients[i] = rng.randi_range(10, 15)
			if rng.randf() < 0.025:
				nutrients[i] = rng.randi_range(17, 22)
			mana[i] = rng.randi_range(0, 3) if y > 17 else 0
	for y in range(4):
		soil[index(Vector2i(30, y))] = 0
	# A reproducible starting pocket teaches the three tiers without free units.
	for y in range(4, 13):
		for x in range(26, 35):
			nutrients[index(Vector2i(x, y))] = 3 + ((x * 3 + y) % 5)
	for pos in [Vector2i(30, 5), Vector2i(28, 7), Vector2i(33, 9), Vector2i(27, 11)]:
		nutrients[index(pos)] = 12
	for pos in [Vector2i(30, 9), Vector2i(32, 12), Vector2i(27, 13)]:
		nutrients[index(pos)] = 19

func index(p: Vector2i) -> int:
	return p.y * WIDTH + p.x

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < WIDTH and p.y >= 0 and p.y < height

func open_at(p: Vector2i) -> bool:
	return inside(p) and soil[index(p)] == 0

func neighbors(p: Vector2i) -> Array:
	var result: Array = []
	for d in DIRS:
		if open_at(p + d):
			result.append(p + d)
	return result

func dig(p: Vector2i) -> bool:
	if not inside(p) or soil[index(p)] == 0 or power <= 0:
		return false
	if neighbors(p).is_empty():
		notice = "通路につながる土から掘ろう。"
		return false
	var i = index(p)
	soil[i] = 0
	power -= 1
	dug += 1
	var n = nutrients[i]
	var m = mana[i]
	nutrients[i] = 0
	mana[i] = 0
	if n > 0:
		var kind = "warden" if n >= 17 else ("beetle" if n >= 10 else "sprout")
		if creatures.size() < MAX_CREATURES:
			spawn(kind, p, n, m)
		else:
			deposit(p, n, m)
	notice = "土の光は養分の濃さ。明るい土から強い生き物が生まれる。"
	return true

func spawn(kind: String, p: Vector2i, food: int, magic: int = 0) -> Dictionary:
	var a = {"id": next_id, "kind": kind, "pos": p, "hp": STATS[kind].hp,
		"max_hp": STATS[kind].hp, "food": food, "mana": magic,
		"dir": Vector2i.DOWN, "cooldown": rng.randf_range(0.1, 0.5),
		"age": 0.0, "breed": 0.0, "flash": 0.0, "dead": false}
	next_id += 1
	creatures.append(a)
	return a

func can_place(p: Vector2i) -> bool:
	return open_at(p) and p != entrance and not path_between(entrance, p).is_empty()

func start_battle(p: Vector2i, solo: bool = false) -> void:
	monarch = p
	heroes.clear()
	carrier = -1
	battle_elapsed = 0.0
	for i in range(1 if solo else 2):
		heroes.append({"id": i, "kind": "knight" if i == 0 else "healer",
			"pos": entrance, "hp": 175.0 if i == 0 else 110.0,
			"max_hp": 175.0 if i == 0 else 110.0, "mp": 72 if i == 1 else 0,
			"attack": 14.0 if i == 0 else 9.0, "defense": 3.0 if i == 0 else 1.0,
			"cooldown": i * 0.7, "heal_cd": 0.0, "visited": {},
			"flash": 0.0, "dead": false})
	notice = "侵入開始。守り手を残して、帰り道でも迎え撃とう。"

func path_between(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal:
		return [start]
	if not open_at(start) or not open_at(goal):
		return []
	var frontier: Array = [start]
	var came: Dictionary = {start: start}
	var head = 0
	while head < frontier.size():
		var cur: Vector2i = frontier[head]
		head += 1
		for n in neighbors(cur):
			if came.has(n):
				continue
			came[n] = cur
			if n == goal:
				var path: Array = [goal]
				var back: Vector2i = goal
				while back != start:
					back = came[back]
					path.push_front(back)
				return path
			frontier.append(n)
	return []

func deposit(p: Vector2i, food: int, magic: int) -> void:
	var placed = 0
	var order = [Vector2i.DOWN, Vector2i(-1, 1), Vector2i(1, 1), Vector2i.LEFT,
		Vector2i.RIGHT, Vector2i.UP, Vector2i(-1, -1), Vector2i(1, -1)]
	for radius in range(1, 4):
		for offset in order:
			var q: Vector2i = p + offset * radius
			if inside(q) and soil[index(q)] == 1:
				if placed < food:
					nutrients[index(q)] += 1
					placed += 1
				if magic > 0:
					mana[index(q)] += 1
					magic -= 1

func remove_creature(a: Dictionary, eaten: bool = false) -> void:
	if a.dead:
		return
	a.dead = true
	if not eaten:
		deposit(a.pos, a.food, a.mana)

func hit_creature(a: Dictionary, amount: float) -> void:
	a.hp -= amount
	a.flash = 0.2
	if a.hp <= 0:
		remove_creature(a)

func hit_hero(h: Dictionary, amount: float) -> void:
	if h.dead:
		return
	h.hp -= maxf(1.0, amount - h.defense)
	h.flash = 0.2
	if h.hp <= 0:
		h.dead = true
		kills += 1
		deposit(h.pos, 24, 8)
		if carrier == h.id:
			monarch = h.pos
			carrier = -1
			rescued += 1
			notice = "救出成功！ 深庭の主がその場で解放された。"
			events.append("rescue")

func tick(dt: float, battle: bool) -> void:
	if not outcome.is_empty():
		return
	elapsed += dt
	if battle:
		battle_elapsed += dt
	for a in creatures.duplicate():
		if a.dead:
			continue
		a.age += dt
		a.breed += dt
		a.flash = maxf(0.0, a.flash - dt)
		a.cooldown -= dt
		if a.cooldown <= 0:
			a.cooldown += STATS[a.kind].period
			creature_action(a, battle)
	if battle:
		for h in heroes:
			if h.dead:
				continue
			h.flash = maxf(0.0, h.flash - dt)
			h.heal_cd -= dt
			h.cooldown -= dt
			if h.cooldown <= 0:
				h.cooldown += 0.68 if h.kind == "knight" else 0.8
				hero_action(h)
				if outcome == "lost":
					break
		if not heroes.is_empty() and heroes.all(func(h): return h.dead) and outcome.is_empty():
			outcome = "won"
			bonus = {"reserve": int(power * 0.2), "army": mini(80, int(army_power() / 10.0)),
				"time": maxi(0, int(70 - elapsed * 0.3))}
			power += bonus.reserve + bonus.army + bonus.time
	creatures = creatures.filter(func(a): return not a.dead)

func creature_action(a: Dictionary, battle: bool) -> void:
	if a.kind == "egg":
		if a.age >= 9:
			a.kind = "warden"
			a.hp = 110.0
			a.max_hp = 165.0
		return
	if battle:
		for h in heroes:
			if not h.dead and distance(a.pos, h.pos) <= 1:
				hit_hero(h, STATS[a.kind].attack)
				return
	# Food chain: consumers incorporate prey energy; no free resource creation.
	if a.kind != "sprout":
		for prey in creatures:
			var edible = (a.kind == "beetle" and prey.kind == "sprout") or (a.kind == "warden" and prey.kind == "beetle")
			if edible and not prey.dead and distance(a.pos, prey.pos) <= 1:
				a.food += prey.food + prey.mana
				a.hp = minf(a.max_hp, a.hp + 20)
				remove_creature(prey, true)
				break
	if a.kind == "sprout":
		for d in DIRS:
			var p: Vector2i = a.pos + d
			if inside(p) and soil[index(p)] == 1 and nutrients[index(p)] > 0:
				if a.food <= 1:
					var amount = mini(3, nutrients[index(p)])
					nutrients[index(p)] -= amount
					a.food += amount
					a.hp = minf(a.max_hp, a.hp + 5)
				else:
					nutrients[index(p)] += a.food - 1
					a.food = 1
				break
	var options = neighbors(a.pos)
	if not options.is_empty():
		var target: Vector2i = options[rng.randi_range(0, options.size() - 1)]
		if a.kind != "beetle" and options.has(a.pos + a.dir):
			target = a.pos + a.dir
		if battle and a.kind == "warden":
			for h in heroes:
				if not h.dead and distance(a.pos, h.pos) <= 6:
					var route = path_between(a.pos, h.pos)
					if route.size() > 1:
						target = route[1]
						break
		a.dir = target - a.pos
		a.pos = target
	a.hp -= 0.15 if a.kind == "sprout" else 0.25
	if a.hp <= 0:
		remove_creature(a)
		return
	if creatures.size() >= MAX_CREATURES:
		return
	if a.kind == "sprout" and a.breed > 16 and a.food >= 4 and a.hp > 10:
		a.food -= 2
		a.hp -= 3
		a.breed = 0
		spawn("sprout", a.pos, 2)
	elif a.kind == "beetle" and a.breed > 22 and a.food >= 18:
		a.food -= 8
		a.breed = 0
		spawn("beetle", a.pos, 8)
	elif a.kind == "warden" and a.breed > 25 and a.food >= 28 and has_nest_space(a.pos):
		a.food -= 10
		a.breed = 0
		if not nests.has(a.pos):
			nests.append(a.pos)
		spawn("egg", a.pos, 10)

func has_nest_space(p: Vector2i) -> bool:
	for oy in range(-2, 1):
		for ox in range(-1, 1):
			var valid = true
			for y in range(3):
				for x in range(2):
					if not open_at(p + Vector2i(ox + x, oy + y)):
						valid = false
			if valid:
				return true
	return false

func hero_action(h: Dictionary) -> void:
	if h.id == carrier:
		if h.pos == entrance:
			outcome = "lost"
			return
		for a in creatures:
			if not a.dead and a.pos == h.pos:
				hit_creature(a, h.attack)
				return
		var route = path_between(h.pos, entrance)
		if route.size() > 1:
			h.pos = route[1]
			monarch = h.pos
		if h.pos == entrance:
			outcome = "lost"
		return
	if carrier < 0 and h.pos == monarch:
		carrier = h.id
		notice = "捕縛！ LBで追跡。出口に着く前に運搬者を倒そう。"
		events.append("capture")
		return
	if h.kind == "healer" and h.mp >= 18 and h.heal_cd <= 0:
		for ally in heroes:
			if not ally.dead and ally.hp <= ally.max_hp * 0.4:
				ally.hp = minf(ally.max_hp, ally.hp + 45)
				h.mp -= 18
				h.heal_cd = 5
				ally.flash = 0.3
				return
	for a in creatures:
		if not a.dead and distance(h.pos, a.pos) <= 1:
			hit_creature(a, h.attack)
			return
	var options = neighbors(h.pos)
	if options.is_empty():
		return
	h.visited[h.pos] = h.visited.get(h.pos, 0) + 1
	var target: Vector2i = options[0]
	var score = INF
	# Local sensing only. Outside 6 cells, least-visited paths with direction bias.
	if carrier < 0 and distance(h.pos, monarch) <= 6:
		var route = path_between(h.pos, monarch)
		if route.size() > 1:
			h.pos = route[1]
			return
	if h.kind == "healer":
		options.reverse()
	for p in options:
		var value = float(h.visited.get(p, 0))
		if value < score:
			score = value
			target = p
	h.pos = target

func army_power() -> int:
	var total = 0
	for a in creatures:
		if not a.dead:
			total += STATS[a.kind].power
	return total

func counts() -> Dictionary:
	var result = {"sprout": 0, "beetle": 0, "warden": 0, "egg": 0}
	for a in creatures:
		if not a.dead:
			result[a.kind] += 1
	return result

func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)

func snapshot() -> Dictionary:
	return {"height": height, "soil": soil.duplicate(), "nutrients": nutrients.duplicate(),
		"mana": mana.duplicate(), "creatures": creatures.duplicate(true), "heroes": heroes.duplicate(true),
		"power": power, "upgraded": upgraded.duplicate(true), "nests": nests.duplicate(true),
		"elapsed": elapsed, "monarch": monarch, "carrier": carrier, "rng_state": rng.state,
		"next_id": next_id, "battle_elapsed": battle_elapsed, "outcome": outcome}

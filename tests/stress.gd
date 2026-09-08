extends SceneTree

const Sim = preload("res://scripts/simulation.gd")

func _initialize() -> void:
	var s = Sim.new(72)
	for y in range(72):
		for x in range(60):
			s.soil[s.index(Vector2i(x, y))] = 0
	for i in range(220):
		s.spawn(["sprout", "beetle", "warden"][i % 3], Vector2i(15 + i % 22, 10 + i / 22), 10)
	s.start_battle(Vector2i(35, 25))
	var peak = 0
	var started = Time.get_ticks_usec()
	for i in range(1000):
		var before = Time.get_ticks_usec()
		s.tick(0.1, true)
		peak = maxi(peak, Time.get_ticks_usec() - before)
	var elapsed = Time.get_ticks_usec() - started
	print("STRESS map=60x72 initial_creatures=220 ticks=1000 total_ms=%.2f peak_tick_ms=%.2f" % [elapsed / 1000.0, peak / 1000.0])
	quit()

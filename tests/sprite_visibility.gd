extends SceneTree
## Read actual rendered pixels: both directions must remain at the same feet.
const Art = preload("res://scripts/character_art.gd")
class Sample extends Node2D:
	var art = Art.new()
	var kind = "sprout"
	var facing = 1
	var feet = Vector2(64,96)
	func _draw() -> void:
		art.draw(self, kind, feet, 0, "idle", facing)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Sprite visibility needs a real renderer; run without --headless.")
		quit(1)
		return
	var viewport = SubViewport.new()
	viewport.size = Vector2i(960,128)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var sample = Sample.new()
	sample.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	viewport.add_child(sample)
	var failures = 0
	for kind in ["sprout", "beetle", "warden", "egg"]:
		for feet_x in [64,320,640,896]:
			var counts = []
			for facing in [1,-1]:
				sample.kind = kind
				sample.facing = facing
				sample.feet.x = feet_x
				sample.queue_redraw()
				await process_frame
				await RenderingServer.frame_post_draw
				var picture = viewport.get_texture().get_image()
				var pixels = 0
				for y in range(32,100):
					for x in range(feet_x-32,feet_x+32):
						if picture.get_pixel(x,y).a > 0.5: pixels += 1
				counts.append(pixels)
			var ok = counts[0] > 100 and counts[0] == counts[1]
			print(("PASS " if ok else "FAIL ") + kind + " x=%d visible pixels right/left: "%feet_x + str(counts))
			if not ok: failures += 1
	print("SPRITE VISIBILITY 16 checks failures=%d" % failures)
	quit(1 if failures else 0)

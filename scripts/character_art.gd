extends RefCounted
## External catalog + optional action rows. Originals are never resampled on disk.
const FALLBACK = preload("res://assets/actors-v2.png")
const KINDS = ["sprout", "beetle", "warden", "knight", "healer", "heart", "egg"]
var entries: Dictionary = {}
var textures: Dictionary = {}
var clip_textures: Dictionary = {}

func _init() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/catalog.json"))
	if parsed is Dictionary:
		for kind in parsed:
			var item = parsed[kind]
			var path = str(item.get("texture", ""))
			if ResourceLoader.exists(path):
				var texture = load(path)
				if texture is Texture2D:
					entries[kind] = item
					textures[kind] = texture
					for clip in item.get("animations",{}).values():
						var clip_path = str(clip.get("texture",""))
						if not clip_path.is_empty() and not clip_textures.has(clip_path) and ResourceLoader.exists(clip_path):
							var clip_texture = load(clip_path)
							if clip_texture is Texture2D: clip_textures[clip_path] = clip_texture

func clip_for(kind: String, action: String) -> Dictionary:
	var clips = entries.get(kind,{}).get("animations",{})
	return clips.get(action,clips.get("idle",{"row":0,"frames":1,"fps":5}))

func scale_for(kind: String, action: String, clock: float) -> float:
	var base = float(entries.get(kind,{}).get("scale",1))
	var clip = clip_for(kind,action)
	var peak = float(clip.get("scale",base))
	if peak == base: return base
	var duration = float(clip.get("frames",1))/maxf(1,float(clip.get("fps",1)))
	return lerpf(base,peak,sin(PI*clampf(clock/duration,0,1)))

func draw(g, kind: String, feet: Vector2, clock: float, action: String = "idle", facing: int = 1, tint: Color = Color.WHITE, bob: float = 0, display_scale: float = 1) -> void:
	var texture: Texture2D = FALLBACK
	var source = Rect2(KINDS.find(kind) * 20, (int(clock * 5) % 4) * 20, 20, 20)
	var size = Vector2(40, 40)
	var anchor = Vector2(20, 36)
	if entries.has(kind):
		var item = entries[kind]
		texture = textures[kind]
		var cell = Vector2(item.cell[0], item.cell[1])
		var scale_value = scale_for(kind,action,clock)
		size = cell * scale_value
		anchor = Vector2(item.anchor[0], item.anchor[1]) * scale_value
		var clip = clip_for(kind,action)
		texture = clip_textures.get(str(clip.get("texture","")),texture)
		var count = maxi(1, int(clip.get("frames", 1)))
		var frame = maxi(0,int(clock * float(clip.get("fps", 5))))
		frame = frame % count if clip.get("loop",true) else mini(frame,count-1)
		source = Rect2(Vector2(frame, int(clip.get("row", 0))) * cell, cell)
	var rect = Rect2((feet - anchor * display_scale + Vector2(0, bob)).round(), size * display_scale)
	if facing < 0 and entries.get(kind,{}).get("mirror",true):
		rect.position.x += rect.size.x
		rect.size.x = -rect.size.x
	g.draw_texture_rect_region(texture, rect, source, tint)

func icon(g, kind: String, feet: Vector2) -> void:
	var multiplier = 1.0 / float(entries[kind].get("scale",1)) if entries.has(kind) else 0.5
	draw(g,kind,feet,0,"idle",1,Color.WHITE,0,multiplier)

extends SceneTree
## Draws icon.png: a house at night with one lit window.  godot --headless --path . --script tools/gen_icon.gd

func _init() -> void:
	var n := 512
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		var sky := Color("0b1020").lerp(Color("27365a"), float(y) / n)
		for x in n:
			im.set_pixel(x, y, sky)
	# stars
	var rng := RandomNumberGenerator.new()
	rng.seed = 1984
	for i in 60:
		im.fill_rect(Rect2i(rng.randi_range(0, n - 3), rng.randi_range(0, 230), 3, 3), Color(1, 1, 0.9, rng.randf_range(0.3, 0.9)))
	# lawn and road
	im.fill_rect(Rect2i(0, 400, n, 112), Color("1d3323"))
	im.fill_rect(Rect2i(0, 452, n, 60), Color("1a1c22"))
	for x in range(20, n, 110):
		im.fill_rect(Rect2i(x, 478, 60, 8), Color("8f8660"))
	# house body and roof
	im.fill_rect(Rect2i(116, 250, 280, 160), Color("3a4258"))
	for y in 110:
		var half := int(170.0 * y / 110.0)
		im.fill_rect(Rect2i(256 - half, 146 + y, half * 2, 1), Color("241a22"))
	# door, dark window, lit window
	im.fill_rect(Rect2i(236, 320, 44, 90), Color("1a1418"))
	im.fill_rect(Rect2i(146, 290, 60, 60), Color("1f2740"))
	im.fill_rect(Rect2i(306, 290, 60, 60), Color("ffd66b"))
	im.fill_rect(Rect2i(334, 290, 4, 60), Color("3a4258"))
	im.fill_rect(Rect2i(306, 318, 60, 4), Color("3a4258"))
	# a figure in the lit window
	im.fill_rect(Rect2i(316, 306, 14, 14), Color("1a1418"))
	im.fill_rect(Rect2i(312, 322, 22, 28), Color("1a1418"))
	im.save_png("res://icon.png")
	quit()

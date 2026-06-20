extends Node

func is_fill(c: Color, fill: Color) -> bool:
	return c.is_equal_approx(fill)

func _ready():
	var img: Image = Image.load_from_file("res://assets/resources/TextBox2.1024.png")
	var w = img.get_width()
	var h = img.get_height()
	print("IMAGE_SIZE: ", w, "x", h)

	var min_x = w
	var max_x = 0
	var min_y = h
	var max_y = 0
	for y in range(h):
		for x in range(w):
			if img.get_pixel(x, y).a > 0.01:
				if x < min_x: min_x = x
				if x > max_x: max_x = x
				if y < min_y: min_y = y
				if y > max_y: max_y = y
	print("BBOX: min_x=", min_x, " max_x=", max_x, " min_y=", min_y, " max_y=", max_y)
	print("BBOX_WIDTH: ", max_x - min_x + 1, " BBOX_HEIGHT: ", max_y - min_y + 1)

	var cx = int((min_x + max_x) / 2.0)
	var cy = int((min_y + max_y) / 2.0)
	var fill_color = img.get_pixel(cx, cy)
	print("FILL_COLOR: ", fill_color)

	var left_thick = -1
	for x in range(min_x, cx):
		var ok = true
		for k in range(6):
			if not is_fill(img.get_pixel(x + k, cy), fill_color):
				ok = false
				break
		if ok:
			left_thick = x - min_x
			break

	var right_thick = -1
	for x in range(max_x, cx, -1):
		var ok = true
		for k in range(6):
			if not is_fill(img.get_pixel(x - k, cy), fill_color):
				ok = false
				break
		if ok:
			right_thick = max_x - x
			break

	var top_thick = -1
	for y in range(min_y, cy):
		var ok = true
		for k in range(6):
			if not is_fill(img.get_pixel(cx, y + k), fill_color):
				ok = false
				break
		if ok:
			top_thick = y - min_y
			break

	var bottom_thick = -1
	for y in range(max_y, cy, -1):
		var ok = true
		for k in range(6):
			if not is_fill(img.get_pixel(cx, y - k), fill_color):
				ok = false
				break
		if ok:
			bottom_thick = max_y - y
			break

	print("LEFT_THICK: ", left_thick, " RIGHT_THICK: ", right_thick)
	print("TOP_THICK: ", top_thick, " BOTTOM_THICK: ", bottom_thick)

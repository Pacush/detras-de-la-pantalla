extends Node

func _ready() -> void:
	var img: Image = Image.load_from_file("res://assets/resources/TextBox2.1024.png")
	var w := img.get_width()
	var h := img.get_height()
	print("IMAGE_SIZE: ", w, "x", h)

	# Detectar color de relleno (centro)
	var fill: Color = img.get_pixel(w / 2, h / 2)
	print("FILL_COLOR: ", fill)

	# Grosor borde izquierdo: desde x=0 hacia el centro en fila central
	var cy := h / 2
	var cx := w / 2
	var left_thick := 0
	for x in range(0, cx):
		if img.get_pixel(x, cy).is_equal_approx(fill):
			left_thick = x
			break

	# Grosor borde derecho: desde x=w-1 hacia el centro
	var right_thick := 0
	for x in range(w - 1, cx, -1):
		if img.get_pixel(x, cy).is_equal_approx(fill):
			right_thick = (w - 1) - x
			break

	# Grosor borde superior: desde y=0 hacia el centro en columna central
	var top_thick := 0
	for y in range(0, cy):
		if img.get_pixel(cx, y).is_equal_approx(fill):
			top_thick = y
			break

	# Grosor borde inferior: desde y=h-1 hacia el centro
	var bottom_thick := 0
	for y in range(h - 1, cy, -1):
		if img.get_pixel(cx, y).is_equal_approx(fill):
			bottom_thick = (h - 1) - y
			break

	print("LEFT_THICK: ", left_thick)
	print("RIGHT_THICK: ", right_thick)
	print("TOP_THICK: ", top_thick)
	print("BOTTOM_THICK: ", bottom_thick)

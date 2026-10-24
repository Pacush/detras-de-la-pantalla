extends RefCounted
## Estilo compartido de menús, botones y selectores (sin class_name: usar con preload).
##
##   const UI = preload("res://scripts/ui/ui_style.gd")
##   root.theme = UI.make_theme()      # paneles, etiquetas, sliders, scrollbars, separadores
##   UI.style_button(btn, 26)          # botón pixel art animado

const C = preload("res://scripts/ui/ui_colors.gd")
const ButtonFx = preload("res://scripts/ui/ui_button_fx.gd")
const PIX_FONT: Font = preload("res://assets/resources/Pix32.ttf")

static var _theme: Theme = null


# ──────────────────────────────────────────────
# THEME GLOBAL DE LOS MENÚS
# ──────────────────────────────────────────────

static func make_theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = Theme.new()
	t.default_font = PIX_FONT
	t.default_font_size = 24

	# Etiquetas
	t.set_font("font", "Label", PIX_FONT)
	t.set_font_size("font_size", "Label", 24)
	t.set_color("font_color", "Label", C.TEXT)

	# Paneles
	t.set_stylebox("panel", "PanelContainer", panel_style())

	# Botones sin estilo animado (los importantes usan style_button)
	var base_btn: StyleBoxFlat = _flat(C.BTN_BG, C.BTN_BORDER, 4)
	var hover_btn: StyleBoxFlat = _flat(C.BTN_BG_HOVER, C.BTN_BORDER_HOVER, 4)
	t.set_stylebox("normal", "Button", base_btn)
	t.set_stylebox("hover", "Button", hover_btn)
	t.set_stylebox("pressed", "Button", hover_btn)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", C.TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_font("font", "Button", PIX_FONT)
	t.set_font_size("font_size", "Button", 24)

	# Separador: línea fina y tenue
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = C.PANEL_BORDER
	line.thickness = 2
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "HSeparator", 14)

	# Sliders: pista oscura, relleno azul pastel y perilla cuadrada
	var track: StyleBoxFlat = _flat(C.SLIDER_TRACK, C.PANEL_BORDER, 2)
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0
	var fill: StyleBoxFlat = _flat(C.SLIDER_FILL, C.SLIDER_FILL, 2)
	fill.content_margin_top = 6.0
	fill.content_margin_bottom = 6.0
	var fill_hi: StyleBoxFlat = _flat(C.SLIDER_FILL_HI, C.SLIDER_FILL_HI, 2)
	fill_hi.content_margin_top = 6.0
	fill_hi.content_margin_bottom = 6.0
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill_hi)
	var knob: ImageTexture = _pixel_icon(22, C.ACCENT, C.BG_DEEP)
	var knob_hi: ImageTexture = _pixel_icon(22, Color.WHITE, C.ACCENT)
	t.set_icon("grabber", "HSlider", knob)
	t.set_icon("grabber_highlight", "HSlider", knob_hi)
	t.set_icon("grabber_disabled", "HSlider", knob)

	# Barra de scroll vertical
	var scroll_track: StyleBoxFlat = _flat(Color(0.05, 0.06, 0.11, 0.9), Color(0.05, 0.06, 0.11, 0.9), 0)
	scroll_track.content_margin_left = 6.0
	scroll_track.content_margin_right = 6.0
	var grab: StyleBoxFlat = _flat(C.ACCENT_DIM, C.ACCENT_DIM, 0)
	grab.content_margin_left = 6.0
	grab.content_margin_right = 6.0
	var grab_hi: StyleBoxFlat = _flat(C.ACCENT, C.ACCENT, 0)
	grab_hi.content_margin_left = 6.0
	grab_hi.content_margin_right = 6.0
	t.set_stylebox("scroll", "VScrollBar", scroll_track)
	t.set_stylebox("scroll_focus", "VScrollBar", scroll_track)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab_hi)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab_hi)

	_theme = t
	return t


static func _flat(bg: Color, border: Color, border_w: int) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	return s


static func _pixel_icon(size: int, fill: Color, border: Color) -> ImageTexture:
	var img: Image = Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	for i: int in size:
		for b: int in 3:
			img.set_pixel(i, b, border)
			img.set_pixel(i, size - 1 - b, border)
			img.set_pixel(b, i, border)
			img.set_pixel(size - 1 - b, i, border)
	return ImageTexture.create_from_image(img)


# ──────────────────────────────────────────────
# PIEZAS REUTILIZABLES
# ──────────────────────────────────────────────

## Panel de submenú: fondo noche, marco azulado grueso y sombra dura.
static func panel_style(border: Color = C.PANEL_BORDER) -> StyleBoxFlat:
	var s: StyleBoxFlat = _flat(C.PANEL_BG, border, 4)
	s.content_margin_left = 28.0
	s.content_margin_right = 28.0
	s.content_margin_top = 22.0
	s.content_margin_bottom = 24.0
	s.shadow_color = C.PANEL_SHADOW
	s.shadow_size = 1
	s.shadow_offset = Vector2(6, 6)
	return s


## Botón pixel art animado (hover/foco/presionado).
static func style_button(btn: Button, font_size: int = 26, min_height: float = 56.0) -> void:
	var fx: Node = ButtonFx.new()
	btn.add_child(fx)
	fx.call("attach", btn, font_size, min_height)


static func style_title(label: Label, font_size: int = 40) -> void:
	label.add_theme_font_override("font", PIX_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", C.TITLE)
	label.add_theme_color_override("font_outline_color", C.BG_BOTTOM)
	label.add_theme_constant_override("outline_size", 6)


## "slot_3" → "Ranura 3"
static func slot_label(slot_name: String) -> String:
	var num: String = slot_name.trim_prefix("slot_")
	if num.is_valid_int():
		return "Ranura %s" % num
	return slot_name


## Nombre legible de la historia de un slot (usa el dato "story" guardado con la partida).
static func story_label(info: Dictionary) -> String:
	var story: String = str(info.get("story", ""))
	if story == "romina":
		return "Historia de Romina"
	if story == "darwin":
		return "Historia de Darwin"
	return "Historia desconocida"   # partidas guardadas antes de registrar la historia


## Fecha y hora actuales (hora local) como texto: "21/10/2026  21:11".
static func now_text() -> String:
	var d: Dictionary = Time.get_datetime_dict_from_system()
	return "%02d/%02d/%04d  %02d:%02d" % [d["day"], d["month"], d["year"], d["hour"], d["minute"]]


## Texto de un slot con datos: ranura + historia, fecha/hora y fragmento del último diálogo.
static func slot_text(slot_name: String, info: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("%s  -  %s" % [slot_label(slot_name), story_label(info)])
	lines.append(str(info.get("saved_at", "Sin fecha")))
	var preview: String = str(info.get("preview", "")).strip_edges().replace("\n", " ")
	if preview != "":
		if preview.length() > 52:
			preview = preview.substr(0, 49) + "..."
		lines.append("\"%s\"" % preview)
	return "\n".join(lines)

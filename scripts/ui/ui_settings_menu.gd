extends "res://scripts/ui/ui_panel_menu.gd"
## Ajustes: volumen principal, velocidad del texto y tamaño del texto (diálogos y nombres).
## Compartido por el menú principal y el de pausa.

const Saved = preload("res://scripts/ui/user_settings.gd")

var _volume_slider: HSlider
var _speed_slider: HSlider
var _dialog_size_slider: HSlider
var _name_size_slider: HSlider
var _volume_value: Label
var _speed_value: Label
var _dialog_size_value: Label
var _name_size_value: Label


func _ready() -> void:
	build_frame("Ajustes", 34)

	var vol_row: Array = _add_slider_row("Volumen principal", 0.0, 1.0, 0.05)
	_volume_slider = vol_row[0]
	_volume_value = vol_row[1]
	var speed_row: Array = _add_slider_row("Velocidad del texto", 0.5, 2.0, 0.1)
	_speed_slider = speed_row[0]
	_speed_value = speed_row[1]
	# Tamaño del texto: 3 pasos (Normal, Grande, Muy grande).
	var max_size: float = float(Saved.TEXT_SIZE_FACTORS.size() - 1)
	var dialog_row: Array = _add_slider_row("Tamaño del diálogo", 0.0, max_size, 1.0)
	_dialog_size_slider = dialog_row[0]
	_dialog_size_value = dialog_row[1]
	var name_row: Array = _add_slider_row("Tamaño de los nombres", 0.0, max_size, 1.0)
	_name_size_slider = name_row[0]
	_name_size_value = name_row[1]

	_load_settings()
	_volume_slider.value_changed.connect(_on_master_volume_changed)
	_speed_slider.value_changed.connect(_on_text_speed_changed)
	_dialog_size_slider.value_changed.connect(_on_dialog_size_changed)
	_name_size_slider.value_changed.connect(_on_name_size_changed)


## Devuelve [HSlider, Label del valor].
func _add_slider_row(label_text: String, min_v: float, max_v: float, step_v: float) -> Array:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(row)

	var lbl: Label = Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(320, 0)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var slider: HSlider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size = Vector2(0, 32)
	slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.add_child(slider)

	var value_label: Label = Label.new()
	value_label.custom_minimum_size = Vector2(190, 0)   # cabe "Muy grande"
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_color_override("font_color", C.ACCENT)
	row.add_child(value_label)

	return [slider, value_label]


func _load_settings() -> void:
	_volume_slider.value = Saved.get_volume()
	_speed_slider.value = Saved.get_speed()
	_dialog_size_slider.value = Saved.get_text_size("dialogo")
	_name_size_slider.value = Saved.get_text_size("nombre")
	_update_labels()


func _update_labels() -> void:
	_volume_value.text = "%d%%" % int(round(_volume_slider.value * 100.0))
	_speed_value.text = "%.1fx" % _speed_slider.value
	_dialog_size_value.text = Saved.TEXT_SIZE_NAMES[int(_dialog_size_slider.value)]
	_name_size_value.text = Saved.TEXT_SIZE_NAMES[int(_name_size_slider.value)]


func _on_master_volume_changed(value: float) -> void:
	Saved.apply_volume(value)
	Saved.save_volume(value)
	_update_labels()


func _on_text_speed_changed(value: float) -> void:
	Saved.apply_speed(value)
	Saved.save_speed(value)
	_update_labels()


func _on_dialog_size_changed(value: float) -> void:
	Saved.save_text_size("dialogo", int(value))
	Saved.apply_text_sizes(get_tree())   # si hay un diálogo en pantalla (menú de pausa), se ve al momento
	_update_labels()


func _on_name_size_changed(value: float) -> void:
	Saved.save_text_size("nombre", int(value))
	Saved.apply_text_sizes(get_tree())
	_update_labels()

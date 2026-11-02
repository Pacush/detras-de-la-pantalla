extends "res://scripts/ui/ui_settings_menu.gd"
## Ajustes del menú principal (casi toda la lógica vive en ui_settings_menu.gd).
## Solo aquí (no en el menú de pausa) hay un botón al final para eliminar todas las partidas
## guardadas. Como no se puede deshacer, pide confirmar: la primera pulsación cambia el texto
## del botón y hay que pulsarlo otra vez antes de que pasen CONFIRM_TIME segundos.

const CONFIRM_TIME: float = 4.0
const TEXT_DELETE: String = "Eliminar partidas guardadas"
const TEXT_CONFIRM: String = "¿Seguro? Pulsa otra vez para eliminarlas"
const COL_DANGER: Color = Color(0.85, 0.42, 0.5)

var _delete_button: Button
var _confirming: bool = false
var _confirm_token: int = 0     # invalida el temporizador de una confirmación anterior


func _ready() -> void:
	super._ready()

	list.add_child(HSeparator.new())
	_delete_button = Button.new()
	_delete_button.text = TEXT_DELETE
	_delete_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(_delete_button)
	UI.style_button(_delete_button, 22, 56.0)
	for color_name: String in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color", "font_hover_pressed_color"]:
		_delete_button.add_theme_color_override(color_name, COL_DANGER)
	_delete_button.pressed.connect(_on_delete_pressed)


func _on_delete_pressed() -> void:
	if not _confirming:
		_confirming = true
		_delete_button.text = TEXT_CONFIRM
		footer.text = ""
		_confirm_token += 1
		var token: int = _confirm_token
		await get_tree().create_timer(CONFIRM_TIME).timeout
		if token == _confirm_token:
			_reset_confirmation()
		return

	_confirm_token += 1
	_reset_confirmation()
	var total: int = _delete_slots(Dialogic.Save.get_slot_names())
	footer.text = "Se eliminaron %d partida(s) guardada(s)." % total if total > 0 else "No había partidas guardadas."


func _reset_confirmation() -> void:
	_confirming = false
	_delete_button.text = TEXT_DELETE


## Borra las ranuras indicadas y devuelve cuántas se eliminaron.
func _delete_slots(slot_names: Array[String]) -> int:
	var eliminadas: int = 0
	for slot: String in slot_names:
		if Dialogic.Save.delete_slot(slot) == OK:
			eliminadas += 1
		else:
			push_warning("[Ajustes] No se pudo eliminar la ranura '%s'." % slot)
	return eliminadas

extends "res://addons/dialogic/Modules/Choice/node_choice_button.gd"
## Botón de decisión de Dialogic con el mismo estilo pixel art que los menús.
## Se usa desde style2 (custom) mediante "choices_custom_button" de la capa de decisiones.

const UI = preload("res://scripts/ui/ui_style.gd")


func _ready() -> void:
	super()   # grupo dialogic_choice_button, hide() y enfoque con el mouse
	UI.style_button(self, 26, 68.0)

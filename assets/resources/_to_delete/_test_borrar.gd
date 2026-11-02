extends Node

func _ready() -> void:
	# Ranura temporal (NO se toca ninguna partida real).
	Dialogic.Save.add_empty_slot("zz_prueba_borrar")
	Dialogic.Save.save_file("zz_prueba_borrar", "info.txt", {"story": "x"})
	print("TEST ranura creada: ", Dialogic.Save.has_slot("zz_prueba_borrar"))

	var menu: Node = load("res://scenes/SettingsMenu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	var botones: Array[Node] = menu.find_children("*", "Button", true, false)
	var textos: Array[String] = []
	for b: Node in botones:
		textos.append((b as Button).text)
	print("TEST botones: ", textos)

	# Primera pulsacion: solo pide confirmar, no borra.
	var boton: Button = botones[botones.size() - 1] as Button
	boton.pressed.emit()
	await get_tree().process_frame
	print("TEST tras 1a pulsacion: '", boton.text, "' | ranura sigue: ", Dialogic.Save.has_slot("zz_prueba_borrar"))

	# Borrado de una ranura concreta (la temporal).
	var lista: Array[String] = ["zz_prueba_borrar"]
	var n: int = menu._delete_slots(lista)
	print("TEST eliminadas: ", n, " | ranura sigue: ", Dialogic.Save.has_slot("zz_prueba_borrar"))

	# La confirmacion caduca sola.
	await get_tree().create_timer(4.3).timeout
	print("TEST tras caducar: '", boton.text, "'")

	# El menu de pausa NO lleva el boton.
	var pausa: Node = load("res://scenes/PauseSettingsMenu.tscn").instantiate()
	add_child(pausa)
	await get_tree().process_frame
	var textos_p: Array[String] = []
	for b: Node in pausa.find_children("*", "Button", true, false):
		textos_p.append((b as Button).text)
	print("TEST botones pausa: ", textos_p)
	print("FIN_TEST")

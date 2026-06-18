extends DialogicAnimation

func animate() -> void:
	var tween = node.create_tween()
	tween.tween_property(node, "position:y", base_position.y - 25, time * 0.3)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(node, "position:y", base_position.y + 15, time * 0.5)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(time * 0.1)
	tween.tween_property(node, "position:y", base_position.y, time * 0.1)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.finished.connect(emit_signal.bind('finished_once'))

func _get_named_variations() -> Dictionary:
	return {
		"shrug": {"type": AnimationType.ACTION},
	}

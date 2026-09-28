extends CanvasLayer
## Fade-to-black scene transitions. Autoload "Transition". Use Transition.go(path).

var _rect: ColorRect
var _busy := false

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.color = Color(0.02, 0.04, 0.07, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

func go(path: String) -> void:
	if _busy:
		return
	_busy = true
	_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(_rect, "color:a", 1.0, 0.22)
	await t.finished
	get_tree().paused = false
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(_rect, "color:a", 0.0, 0.3)
	await t2.finished
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false

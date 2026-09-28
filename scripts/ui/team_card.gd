class_name TeamCard
extends Control
## Clickable team card: logo, name, rating bars.

signal chosen(index: int)

var index := 0
var data: TeamData
var selected := false
var accent := Color("#19d3a2")
var _hover := false

func setup(i: int, td: TeamData) -> void:
	index = i
	data = td
	custom_minimum_size = Vector2(128, 152)
	pivot_offset = custom_minimum_size * 0.5
	mouse_entered.connect(func() -> void:
		_hover = true
		AudioManager.play("hover", -8.0)
		create_tween().tween_property(self, "scale", Vector2(1.06, 1.06), 0.1)
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		create_tween().tween_property(self, "scale", Vector2.ONE, 0.1)
		queue_redraw())

func set_selected(v: bool) -> void:
	selected = v
	queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		AudioManager.play("click")
		chosen.emit(index)
	elif e is InputEventScreenTouch and e.pressed:
		chosen.emit(index)

func _draw() -> void:
	if data == null:
		return
	var r := Rect2(Vector2.ZERO, custom_minimum_size)
	draw_rect(r, Color(0.08, 0.12, 0.2, 0.95) if not _hover else Color(0.12, 0.18, 0.3, 0.95))
	if selected:
		draw_rect(r, accent, false, 4.0)
	else:
		draw_rect(r, Color(1, 1, 1, 0.12), false, 2.0)
	data.draw_logo(self, Vector2(64, 42), 56.0)
	var f := ThemeDB.fallback_font
	var w := f.get_string_size(data.team_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(f, Vector2(64.0 - w * 0.5, 88.0), data.team_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
	var labels := ["ATK", "MID", "DEF", "GK"]
	var vals := [data.attack, data.midfield, data.defense, data.goalkeeper]
	for i in 4:
		var y := 98.0 + i * 13.0
		draw_string(f, Vector2(8, y + 8.0), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, UIKit.COL_DIM)
		draw_rect(Rect2(38, y, 82, 7), Color(0, 0, 0, 0.5))
		var frac := clampf((float(vals[i]) - 40.0) / 60.0, 0.0, 1.0)
		draw_rect(Rect2(38, y, 82.0 * frac, 7), data.primary.lerp(UIKit.COL_ACCENT, 0.5) if data.primary.get_luminance() < 0.15 else data.primary)

class_name UIKit
extends RefCounted
## Shared UI helpers: consistent palette, styled buttons/labels, hover animations.

const COL_BG := Color("#0b1220")
const COL_PANEL := Color(0.05, 0.08, 0.14, 0.92)
const COL_ACCENT := Color("#19d3a2")
const COL_ACCENT2 := Color("#ffb020")
const COL_TEXT := Color("#eef3ff")
const COL_DIM := Color("#8a98b5")

static func box(color: Color, radius: int = 10, border: Color = Color(0, 0, 0, 0), border_w: int = 0, pad: int = -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	if pad >= 0:
		sb.set_content_margin_all(pad)
	return sb

static func label(text: String, size: int = 22, color: Color = COL_TEXT, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align as HorizontalAlignment
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", maxi(2, int(size * 0.08)))
	return l

static func button(text: String, size: int = 26, min_size: Vector2 = Vector2(300, 56), accent: Color = COL_ACCENT) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", box(Color(0.1, 0.15, 0.25, 0.92), 12, Color(1, 1, 1, 0.12), 2))
	b.add_theme_stylebox_override("hover", box(accent.darkened(0.2), 12, accent.lightened(0.3), 3))
	b.add_theme_stylebox_override("pressed", box(accent.darkened(0.45), 12, accent, 3))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), 12, accent, 3))
	b.add_theme_stylebox_override("disabled", box(Color(0.1, 0.12, 0.18, 0.6), 12))
	b.resized.connect(func() -> void: b.pivot_offset = b.size * 0.5)
	b.mouse_entered.connect(func() -> void: _hover(b, true))
	b.mouse_exited.connect(func() -> void: _hover(b, false))
	b.pressed.connect(func() -> void: AudioManager.play("click"))
	return b

static func _hover(b: Button, on: bool) -> void:
	if b.disabled:
		return
	if on:
		AudioManager.play("hover", -8.0)
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(1.05, 1.05) if on else Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK)

static func panel(color: Color = COL_PANEL, radius: int = 16, pad: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius, Color(1, 1, 1, 0.1), 2, pad))
	return p

static func slide_in(c: Control, delay: float, from: Vector2 = Vector2(-80, 0)) -> void:
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.35).set_delay(delay)
	c.position += from
	tw.tween_property(c, "position", c.position - from, 0.35).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func draw_ball(c: CanvasItem, pos: Vector2, r: float, rot: float) -> void:
	c.draw_circle(pos, r, Color.WHITE)
	var pts := PackedVector2Array()
	for i in 5:
		pts.append(pos + Vector2.from_angle(rot + TAU * i / 5.0) * r * 0.45)
	c.draw_colored_polygon(pts, Color(0.12, 0.12, 0.16))
	for i in 5:
		var d := Vector2.from_angle(rot + TAU * i / 5.0)
		c.draw_line(pos + d * r * 0.45, pos + d * r * 0.95, Color(0.2, 0.2, 0.25), maxf(1.0, r * 0.08))
	c.draw_arc(pos, r, 0.0, TAU, 28, Color(0.25, 0.25, 0.3), maxf(1.0, r * 0.08))

class_name TeamData
extends Resource
## Reusable team definition. Create new teams by adding a .tres file in res://data/teams/.

@export var team_name: String = "Team"
@export var short_name: String = "TEM"
@export var primary: Color = Color.RED
@export var secondary: Color = Color.WHITE
@export_enum("Shield", "Circle", "Diamond", "Star", "Chevron") var logo_shape: int = 0
@export_range(30, 99) var attack: int = 70
@export_range(30, 99) var midfield: int = 70
@export_range(30, 99) var defense: int = 70
@export_range(30, 99) var goalkeeper: int = 70
@export var formation: String = "4-4-2"

func overall() -> int:
	return roundi((attack + midfield + defense + goalkeeper * 0.6) / 3.6)

## Draws the procedural logo. Must be called from inside a CanvasItem's _draw().
func draw_logo(c: CanvasItem, center: Vector2, size: float) -> void:
	var r := size * 0.5
	var outline := secondary if primary.get_luminance() > 0.12 else Color(0.85, 0.85, 0.9)
	var pts := PackedVector2Array()
	match logo_shape:
		0, 4:
			for p in [Vector2(-0.85, -0.9), Vector2(0.85, -0.9), Vector2(0.85, 0.1), Vector2(0.0, 1.0), Vector2(-0.85, 0.1)]:
				pts.append(center + p * r)
		1:
			for i in 28:
				pts.append(center + Vector2.from_angle(TAU * i / 28.0) * r)
		2:
			for p in [Vector2(0, -1), Vector2(0.9, 0), Vector2(0, 1), Vector2(-0.9, 0)]:
				pts.append(center + p * r)
		3:
			for i in 10:
				var rad := r if i % 2 == 0 else r * 0.45
				pts.append(center + Vector2.from_angle(-PI * 0.5 + TAU * i / 10.0) * rad)
	c.draw_colored_polygon(pts, primary)
	var closed := pts.duplicate()
	closed.append(pts[0])
	c.draw_polyline(closed, outline, maxf(2.0, size * 0.05))
	if logo_shape == 4:
		c.draw_line(center + Vector2(-0.85, -0.3) * r, center + Vector2(0, 0.35) * r, secondary, size * 0.1)
		c.draw_line(center + Vector2(0, 0.35) * r, center + Vector2(0.85, -0.3) * r, secondary, size * 0.1)
	elif logo_shape != 3:
		var font := ThemeDB.fallback_font
		var fs := int(size * 0.5)
		var txt := team_name.substr(0, 1)
		var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(font, center + Vector2(-w * 0.5, fs * 0.33), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, outline)

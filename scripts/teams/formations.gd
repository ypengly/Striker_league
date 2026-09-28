class_name Formations
extends RefCounted
## Formation layouts. Slot = [x, y, role]. x: 0 = own goal line .. 1 = opposition goal line,
## y: -1 (top touchline) .. 1 (bottom touchline). Role ints match Player.Role (0 GK,1 DEF,2 MID,3 WING,4 STR).
## Slot 0 is always the goalkeeper, slot 10 always a striker.

const NAMES := ["4-4-2", "4-3-3", "3-5-2", "4-2-3-1"]
const LAYOUTS := {
	"4-4-2": [[0.02, 0.0, 0],
		[0.22, -0.68, 1], [0.19, -0.24, 1], [0.19, 0.24, 1], [0.22, 0.68, 1],
		[0.50, -0.72, 3], [0.44, -0.22, 2], [0.44, 0.22, 2], [0.50, 0.72, 3],
		[0.74, -0.2, 4], [0.76, 0.2, 4]],
	"4-3-3": [[0.02, 0.0, 0],
		[0.22, -0.68, 1], [0.19, -0.24, 1], [0.19, 0.24, 1], [0.22, 0.68, 1],
		[0.46, -0.4, 2], [0.40, 0.0, 2], [0.46, 0.4, 2],
		[0.74, -0.7, 3], [0.74, 0.7, 3], [0.82, 0.0, 4]],
	"3-5-2": [[0.02, 0.0, 0],
		[0.20, -0.5, 1], [0.17, 0.0, 1], [0.20, 0.5, 1],
		[0.46, -0.85, 3], [0.46, 0.85, 3], [0.45, -0.3, 2], [0.38, 0.0, 2], [0.45, 0.3, 2],
		[0.76, -0.2, 4], [0.76, 0.2, 4]],
	"4-2-3-1": [[0.02, 0.0, 0],
		[0.22, -0.68, 1], [0.19, -0.24, 1], [0.19, 0.24, 1], [0.22, 0.68, 1],
		[0.40, -0.25, 2], [0.40, 0.25, 2],
		[0.62, -0.7, 3], [0.60, 0.0, 2], [0.62, 0.7, 3],
		[0.82, 0.0, 4]],
}
const ROLE_ADVANCE := [0.0, 0.7, 1.0, 1.1, 0.8]

static func get_layout(formation: String) -> Array:
	return LAYOUTS.get(formation, LAYOUTS["4-4-2"])

## Converts a formation slot to a world position. The whole shape slides with the ball.
static func world_pos(slot: Array, side: int, ball_pos: Vector2, has_ball: bool, kickoff: bool, shift: float = 1.0) -> Vector2:
	var role: int = slot[2]
	var xn: float = slot[0]
	if role != 0:
		var prog := clampf((ball_pos.x * side / Pitch.HALF_W + 1.0) * 0.5, 0.0, 1.0)
		xn += (prog - 0.5) * 0.36 * ROLE_ADVANCE[role] * shift
		xn += (0.06 if has_ball else -0.04)
	if kickoff:
		xn = minf(xn, 0.46)
	xn = clampf(xn, 0.02, 0.95)
	var x := side * (xn * 2.0 - 1.0) * Pitch.HALF_W * 0.94
	var y: float = float(slot[1]) * Pitch.HALF_H * 0.86
	if role != 0 and not kickoff:
		y = lerpf(y, ball_pos.y, 0.16 * shift)
	return Vector2(x, y)

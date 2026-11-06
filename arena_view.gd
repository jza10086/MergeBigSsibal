## Draw-only view of host snapshots; the large bin always belongs to the local player.
extends Control
const World: Script = preload("res://games/minigame/godot_party_default_merge_big_ssibal/merge_world.gd")
const COLORS: Array[Color] = [Color("#ef6684"), Color("#b285ec"), Color("#7b8def"), Color("#59bde8"), Color("#58d6c0"), Color("#9bd36b"), Color("#e6d767"), Color("#efa352"), Color("#ef7951"), Color("#de5985"), Color("#53c58b")]
var snapshot: Dictionary = {}
var focus_id: String = ""
var aim: float = 250.0
var font: Font
var names: Dictionary[String, String] = {}

func bin_rect() -> Rect2:
	var scale_value: float = minf((size.y - 180.0) / World.HEIGHT, (size.x - 180.0) / World.WIDTH)
	var dimensions: Vector2 = Vector2(World.WIDTH, World.HEIGHT) * scale_value
	return Rect2((size - dimensions) * 0.5 + Vector2(0, 15), dimensions)

func mouse_aim() -> float:
	var rect: Rect2 = bin_rect()
	return clampf((get_local_mouse_position().x - rect.position.x) / rect.size.x * World.WIDTH, 0.0, World.WIDTH)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#101c27"))
	if snapshot.is_empty():
		return
	var rect: Rect2 = bin_rect()
	_draw_bin(focus_id, rect, true)
	var index: int = 0
	for id: String in snapshot.boards:
		if id == focus_id:
			continue
		var column: int = index / 4
		var row: int = index % 4
		_draw_bin(id, Rect2(Vector2(60 + column * (size.x - 240), 150 + row * 205), Vector2(115, 175)), false)
		index += 1
	var board: Dictionary = snapshot.boards[focus_id]
	var s: float = rect.size.x / World.WIDTH
	draw_string(font, rect.position + Vector2(rect.size.x + 28, 30), "下一球", HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	draw_circle(rect.position + Vector2(rect.size.x + 65, 95), World.RADII[board.following] * s, COLORS[board.following])
	for level: int in range(COLORS.size()):
		draw_circle(Vector2(size.x * 0.5 - 220 + level * 44, size.y - 36), 9.0 + level * 0.7, COLORS[level])

func _draw_bin(id: String, rect: Rect2, main: bool) -> void:
	var board: Dictionary = snapshot.boards[id]
	var s: float = rect.size.x / World.WIDTH
	draw_rect(rect, Color("#1a2d3a"))
	draw_rect(rect, Color("#547080"), false, 3.0)
	var line_y: float = rect.position.y + World.LIMIT * s
	draw_dashed_line(Vector2(rect.position.x, line_y), Vector2(rect.end.x, line_y), Color("#f18780"), 2.0, 8.0)
	for ball: Dictionary in board.balls:
		draw_circle(rect.position + Vector2(ball.x, ball.y) * s, World.RADII[ball.level] * s, COLORS[ball.level])
	var caption: String = "%s · %d" % [names[id], board.score]
	if board.over:
		caption += "  已结束"
	draw_string(font, rect.position - Vector2(0, 12), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 24 if main else 16)
	if main and not board.over:
		var x: float = clampf(aim, World.RADII[board.next], World.WIDTH - World.RADII[board.next])
		var point: Vector2 = rect.position + Vector2(x, 42) * s
		draw_dashed_line(point, Vector2(point.x, rect.end.y), Color(1, 1, 1, 0.15), 1.0, 7.0)
		draw_circle(point, World.RADII[board.next] * s, Color(COLORS[board.next], 0.5))
		if board.danger > 0.0:
			draw_string(font, rect.position + Vector2(18, 135) * s, "即将溢出 %.1f" % maxf(0, 2.0 - board.danger), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color("#ff9c90"))

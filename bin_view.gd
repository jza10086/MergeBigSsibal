## One editable bin skin; only live balls, aim and danger line are drawn.
extends Panel
const World: Script = preload("merge_world.gd")
var board: Dictionary = {}
var palette: Array[Color] = []
var aim: float = 250.0
var primary: bool = false
@onready var caption: Label = %Caption
@onready var warning: Label = %Warning

func present(value: Dictionary, colors: Array[Color], title: String, danger: String) -> void:
	board = value
	palette = colors
	caption.text = title
	warning.text = danger
	warning.visible = primary and board.danger > 0.0 and not board.over
	queue_redraw()

func _draw() -> void:
	var scale_value: float = size.x / World.WIDTH
	var line_y: float = World.LIMIT * scale_value
	draw_dashed_line(Vector2(0, line_y), Vector2(size.x, line_y), Color("#f18780"), 2.0, 8.0)
	if board.is_empty():
		return
	for ball: Dictionary in board.balls:
		draw_circle(Vector2(ball.x, ball.y) * scale_value, World.RADII[ball.level] * scale_value, palette[ball.level])
	if primary and not board.over:
		var x: float = clampf(aim, World.RADII[board.next], World.WIDTH - World.RADII[board.next])
		var point: Vector2 = Vector2(x, 42) * scale_value
		draw_dashed_line(point, Vector2(point.x, size.y), Color(1, 1, 1, 0.15), 1.0, 7.0)
		draw_circle(point, World.RADII[board.next] * scale_value, Color(palette[board.next], 0.5))

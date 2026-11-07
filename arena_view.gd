## Snapshot presentation only. Bin skins and fixed labels/legend are authored scenes.
extends Control
const World: Script = preload("merge_world.gd")
const Bin: Script = preload("bin_view.gd")
const BIN_SCENE: PackedScene = preload("bin_view.tscn")
const DEFAULT_TEXT: Translation = preload("i18n/zh_Hans.po")
const COLORS: Array[Color] = [Color("#ef6684"), Color("#b285ec"), Color("#7b8def"), Color("#59bde8"), Color("#58d6c0"), Color("#9bd36b"), Color("#e6d767"), Color("#efa352"), Color("#ef7951"), Color("#de5985"), Color("#53c58b")]
var snapshot: Dictionary = {}
var focus_id: String = ""
var aim: float = 250.0
var names: Dictionary[String, String] = {}
var translate: Callable = _default_text
var bins: Dictionary[String, Bin] = {}
@onready var main_bin: Bin = %MainBin
@onready var next_title: Label = %NextTitle
@onready var opponents: Control = %Opponents

func _ready() -> void:
	next_title.text = translate.call(&"merge.next", {})
	main_bin.primary = true

func _default_text(key: StringName, parameters: Dictionary = {}) -> String:
	return String(DEFAULT_TEXT.get_message(key)).format(parameters)

func configure(text: Callable, font: Font) -> void:
	translate = text
	theme = Theme.new()
	theme.default_font = font
	next_title.text = translate.call(&"merge.next", {})

func bin_rect() -> Rect2:
	return main_bin.get_rect()

func mouse_aim() -> float:
	var rect: Rect2 = bin_rect()
	return clampf((get_local_mouse_position().x - rect.position.x) / rect.size.x * World.WIDTH, 0.0, World.WIDTH)

func accept(value: Dictionary) -> void:
	snapshot = value
	var index: int = 0
	for id: String in snapshot.boards:
		var bin_view: Bin
		if id == focus_id:
			bin_view = main_bin
		else:
			if not bins.has(id):
				bin_view = BIN_SCENE.instantiate()
				opponents.add_child(bin_view)
				bin_view.caption.add_theme_font_size_override("font_size", 16)
				bins[id] = bin_view
			bin_view = bins[id]
			bin_view.position = Vector2(60 + (index / 4) * (size.x - 240), 150 + (index % 4) * 205)
			bin_view.size = Vector2(115, 175)
			index += 1
		var board: Dictionary = snapshot.boards[id]
		var key: StringName = &"merge.bin_ended" if board.over else &"merge.bin"
		bin_view.present(board, COLORS, translate.call(key, {"name": names[id], "score": board.score}),
			translate.call(&"merge.overflow", {"seconds": "%.1f" % maxf(0.0, 2.0 - board.danger)}))
	queue_redraw()

func _draw() -> void:
	if snapshot.is_empty():
		return
	main_bin.aim = aim
	main_bin.queue_redraw()
	var rect: Rect2 = bin_rect()
	var board: Dictionary = snapshot.boards[focus_id]
	draw_circle(rect.position + Vector2(rect.size.x + 65, 95), World.RADII[board.following] * rect.size.x / World.WIDTH, COLORS[board.following])

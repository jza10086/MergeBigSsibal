## Standard ranked round: host simulation, participant-only logical drops, shared round pages.
extends "res://games/protocols/godot_party_default_protocol/ranked_round.gd"
const World: Script = preload("res://games/minigame/godot_party_default_merge_big_ssibal/merge_world.gd")
const Arena: Script = preload("res://games/minigame/godot_party_default_merge_big_ssibal/arena_view.gd")
var world: World = World.new()
var accumulator: float = 0.0
var revision: int = 0
var aim: float = 250.0
@onready var arena: Arena = %Arena

func build_game() -> void:
	heading.text = api.i18n.text(&"合成大西八")
	footer.text = api.i18n.text(&"merge.controls", {"drop": api.input.binding_text(&"merge_drop")})
	arena.configure(api.i18n.text, api.load_asset({"package_id": "godot_party_default_protocol", "resource_key": "font_sans"}) as Font)
	for player: Dictionary in players:
		arena.names[player.player_id] = player.name
	arena.focus_id = local_id if not local_id.is_empty() else players[0].player_id

func start_game() -> void:
	if api.is_host():
		var ids: Array[String] = []
		for player: Dictionary in players:
			ids.append(player.player_id)
		world.reset(ids, api.get_seed(), float(settings.duration))
		_players_changed()

func tick_game(delta: float) -> void:
	# Poll while released so the public input gate rearms after menus and briefing.
	api.input.is_pressed(&"merge_drop")
	if not api.input.input_blocked:
		aim = arena.mouse_aim()
		arena.aim = aim

	arena.queue_redraw()
	if not api.is_host():
		return
	accumulator += delta
	while accumulator >= World.STEP and not world.complete():
		accumulator -= World.STEP
		world.tick(World.STEP)
	if world.complete():
		publish()
		var scores: Dictionary = {}
		for id: String in world.boards:
			scores[id] = world.boards[id].score
		finish_scores(scores)

func _unhandled_input(event: InputEvent) -> void:
	if running and not api.input.input_blocked and api.input.event_matches(event, &"merge_drop"):
		send_action({"x": arena.mouse_aim()})

func handle_action(id: String, data: Dictionary) -> void:
	if not (data.get("x") is float or data.get("x") is int):
		return
	var x: float = float(data.x)
	if not is_finite(x) or x < 0.0 or x > World.WIDTH:
		return
	world.drop(id, x)

func make_snapshot() -> Dictionary:
	return world.snapshot()

func render_game() -> void:
	if view.is_empty():
		return
	arena.accept(view)
	status.text = api.i18n.text(&"merge.time", {"seconds": "%03d" % maxi(0, ceili(view.duration - view.time))})
	for id: String in view.boards:
		var key: StringName = &"merge.standing_ended" if view.boards[id].over else &"merge.standing"
		update_standing(id, api.i18n.text(key, {"name": player_name(id), "score": view.boards[id].score}))
	arena.queue_redraw()

func player_left(id: String) -> void:
	world.withdraw(id)

## Explicitly propagate transport failure rather than continuing a desynchronized round.
func send_action(data: Dictionary) -> void:
	if not running or local_id.is_empty():
		return
	sequence += 1
	data.seq = sequence
	var error: Error = api.net.send_to_host(&"action", data)
	if error != OK:
		_fail_transport(error)

func publish() -> void:
	revision += 1
	var snapshot: Dictionary = make_snapshot()
	snapshot._sequence = revision
	var error: Error = api.net.broadcast_stream(&"state", snapshot)
	if error != OK:
		_fail_transport(error)
		return
	view = snapshot
	render_game()

func _fail_transport(error: Error) -> void:
	running = false
	api.fail("merge_transport", error_string(error))

func party_stop(reason: StringName) -> void:
	super.party_stop(reason)
	if api.net.message_received.is_connected(_message):
		api.net.message_received.disconnect(_message)
	if api.players_changed.is_connected(_players_changed):
		api.players_changed.disconnect(_players_changed)

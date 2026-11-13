## Standard ranked round: host simulation, participant-only logical drops, shared round pages.
extends "res://games/protocols/godot_party_default_protocol/ranked_round.gd"

## Content-owned gameplay rules, independent of package compatibility.
static func party_definition() -> Dictionary:
	return {"player_counts": [1, 2, 3, 4, 5, 6, 7, 8], "tags": ["original", "arcade", "puzzle"], "controls": {"merge_drop": "落球"}}

const World: Script = preload("res://games/minigame/gp_merge_ssibal/merge_world.gd")
const Arena: Script = preload("res://games/minigame/gp_merge_ssibal/arena_view.gd")
var world: World = World.new()
var accumulator: float = 0.0
var network_clock: float = 0.0
var revision: int = 0
var _published_boards: Dictionary = {}
var _published_balls: Dictionary = {}
var _objects: Dictionary = {}
var _targets: Dictionary = {}
var _received_event: int = 0
var _sample: int = 0
var _received_sample: int = 0
var _pending_motion: Dictionary = {}
var _end_msec: int = 0
var aim: float = 250.0
@onready var arena: Arena = %Arena

func build_game() -> void:
	heading.text = api.i18n.text(&"合成大西八")
	footer.text = api.i18n.text(&"merge.controls", {"drop": api.input.binding_text(&"merge_drop")})
	arena.configure(api.i18n.text, preload("res://games/assets/godot_party_default_ui/fonts/NotoSansSC-UI.otf"))
	for player: Dictionary in players:
		arena.names[player.player_id] = player.name
	arena.focus_id = local_id if not local_id.is_empty() else players[0].player_id

func start_game() -> void:
	if api.is_host():
		var ids: Array[String] = []
		for player: Dictionary in players:
			ids.append(player.player_id)
		world.reset(ids, api.get_seed(), float(settings.duration))
		_end_msec = api.net.host_time_msec() + roundi(float(settings.duration) * 1000.0)
		_players_changed()

func tick_game(delta: float) -> void:
	# Poll while released so the public input gate rearms after menus and briefing.
	api.input.is_pressed(&"merge_drop")
	if not api.input.input_blocked:
		aim = arena.mouse_aim()
		arena.aim = aim

	if not api.is_host():
		for id: int in _targets:
			var ball: Dictionary = _objects[id]
			var point: Vector2 = Vector2(ball.x, ball.y).lerp(_targets[id], 1.0 - exp(-25.0 * delta))
			ball.x = point.x
			ball.y = point.y
		if not view.is_empty():
			for board: Dictionary in view.boards.values():
				board.danger = 0.0 if board.danger_start_msec < 0 else maxf(0.0, float(api.net.host_time_msec() - board.danger_start_msec) / 1000.0)
		arena.queue_redraw()
		return
	arena.queue_redraw()
	accumulator += delta
	while accumulator >= World.STEP and not world.complete():
		accumulator -= World.STEP
		world.tick(World.STEP)
	network_clock += delta
	if network_clock >= 0.05:
		network_clock = 0.0
		publish()
		if not running:
			return
	if world.complete():
		publish()
		if not running:
			return
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
	status.text = api.i18n.text(&"merge.time", {"seconds": "%03d" % maxi(0, ceili(float(_end_msec - api.net.host_time_msec()) / 1000.0))})
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
	if not running or not api.is_host():
		return
	var updates: Dictionary = {}
	var live: Dictionary = {}
	var poses: Dictionary = {}
	for owner: String in world.boards:
		var board: Dictionary = world.boards[owner]
		var previous: Dictionary = _published_boards.get(owner, {})
		var facts: Dictionary = {}
		for key: String in ["score", "best", "over", "withdrawn", "next", "following"]:
			if not previous.has(key) or previous[key] != board[key]:
				facts[key] = board[key]
		if previous.is_empty() or (previous.danger > 0.0) != (board.danger > 0.0):
			facts["danger_start_msec"] = api.net.host_time_msec() - roundi(board.danger * 1000.0) if board.danger > 0.0 else -1
		var spawned: Array = []
		var stopped: Dictionary = {}
		for ball: Dictionary in board.balls:
			var old: Dictionary = _published_balls.get(ball.id, {})
			var point: Vector2 = Vector2(ball.x, ball.y)
			var moving: bool = old.is_empty() or point.distance_squared_to(old.point) > 0.0001
			live[ball.id] = {"owner": owner, "point": point, "moving": moving}
			if old.is_empty():
				spawned.append({"id": ball.id, "level": ball.level, "x": ball.x, "y": ball.y})
			elif moving:
				poses[ball.id] = point
			elif old.moving:
				stopped[ball.id] = point
		var removed: Array[int] = []
		for id: int in _published_balls:
			if _published_balls[id].owner == owner and not live.has(id):
				removed.append(id)
		if not facts.is_empty() or not spawned.is_empty() or not removed.is_empty() or not stopped.is_empty():
			updates[owner] = {"facts": facts, "spawned": spawned, "removed": removed, "stopped": stopped}
		_published_boards[owner] = {"score": board.score, "best": board.best, "over": board.over,
			"withdrawn": board.withdrawn, "next": board.next, "following": board.following, "danger": board.danger}
	if not updates.is_empty() or revision == 0:
		revision += 1
		var event: Dictionary = {"revision": revision, "boards": updates}
		if revision == 1:
			event["end_msec"] = _end_msec
		var error: Error = api.net.broadcast(&"merge/events", event, MultiplayerPeer.TRANSFER_MODE_RELIABLE, false)
		if error != OK:
			_fail_transport(error)
			return
	_published_balls = live
	if not poses.is_empty():
		_sample += 1
		var error: Error = api.net.broadcast(&"merge/motion", {"revision": revision, "sample": _sample, "poses": poses}, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, false, "instance", 1)
		if error != OK:
			_fail_transport(error)
			return
	view = world.snapshot()
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

func _message(sender: Dictionary, topic: StringName, payload: Variant) -> void:
	if topic not in [&"merge/events", &"merge/motion"]:
		super._message(sender, topic, payload)
		return
	if not running or api.is_host() or sender.peer_id != 1 or not payload is Dictionary or not payload.get("revision") is int:
		return
	if topic == &"merge/motion":
		if not payload.get("sample") is int or not payload.get("poses") is Dictionary or payload.sample <= _received_sample or payload.revision < _received_event:
			return
		_received_sample = payload.sample
		if payload.revision > _received_event:
			_pending_motion = payload
		else:
			_apply_motion(payload)
		return
	if payload.revision <= _received_event or not payload.get("boards") is Dictionary:
		return
	if payload.revision != _received_event + 1:
		_fail_transport(ERR_INVALID_DATA)
		return
	if view.is_empty():
		view = {"boards": {}}
	for owner: Variant in payload.boards:
		if not owner is String:
			return
		var known: bool = false
		for player: Dictionary in players:
			if player.player_id == owner:
				known = true
		var event: Variant = payload.boards[owner]
		if not known or not event is Dictionary or not event.get("facts") is Dictionary or not event.get("spawned") is Array or not event.get("removed") is Array or not event.get("stopped") is Dictionary:
			return
		if not view.boards.has(owner):
			view.boards[owner] = {"balls": [], "danger": 0.0, "danger_start_msec": -1}
		var board: Dictionary = view.boards[owner]
		board.merge(event.facts, true)
		for ball: Variant in event.spawned:
			if not ball is Dictionary or not ball.get("id") is int or not ball.get("level") is int or ball.level < 0 or ball.level >= World.RADII.size() or not (ball.get("x") is float or ball.get("x") is int) or not (ball.get("y") is float or ball.get("y") is int) or not is_finite(float(ball.x)) or not is_finite(float(ball.y)):
				return
			if not _objects.has(ball.id):
				_objects[ball.id] = ball.duplicate()
				board.balls.append(_objects[ball.id])
		for id: Variant in event.removed:
			if not id is int:
				return
			if _objects.has(id):
				board.balls.erase(_objects[id])
				_objects.erase(id)
				_targets.erase(id)
		for id: Variant in event.stopped:
			if not id is int or not event.stopped[id] is Vector2 or not event.stopped[id].is_finite():
				return
			if _objects.has(id):
				_targets[id] = event.stopped[id]
	if payload.has("end_msec"):
		if not payload.end_msec is int:
			return
		_end_msec = payload.end_msec
	_received_event = payload.revision
	if not _pending_motion.is_empty() and _pending_motion.revision <= _received_event:
		if _pending_motion.revision == _received_event:
			_apply_motion(_pending_motion)
		_pending_motion.clear()
	render_game()

func _apply_motion(payload: Dictionary) -> void:
	for id: Variant in payload.poses:
		if id is int and _objects.has(id) and payload.poses[id] is Vector2 and payload.poses[id].is_finite():
			_targets[id] = payload.poses[id]

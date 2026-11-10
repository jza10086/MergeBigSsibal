## Host-owned fixed-step circle simulation. Each participant has an independent bin.
extends RefCounted
const RADII: Array[float] = [16.0, 22.0, 29.0, 37.0, 46.0, 56.0, 67.0, 79.0, 92.0, 106.0, 122.0]
const WIDTH: float = 500.0
const HEIGHT: float = 760.0
const LIMIT: float = 100.0
const STEP: float = 1.0 / 60.0
var boards: Dictionary = {}
var time: float = 0.0
var next_ball_id: int = 0
var duration: float = 180.0

func reset(ids: Array[String], seed_value: int, seconds: float) -> void:
	boards.clear()
	next_ball_id = 0
	time = 0.0
	duration = seconds
	for id: String in ids:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = seed_value
		boards[id] = {"balls": [], "score": 0, "best": 0, "over": false, "withdrawn": false,
			"danger": 0.0, "cooldown": 0.0, "rng": rng, "next": rng.randi_range(0, 4), "following": rng.randi_range(0, 4)}

func drop(id: String, x: float) -> void:
	var board: Dictionary = boards[id]
	if board.over or board.cooldown > 0.0:
		return
	var level: int = board.next
	var radius: float = RADII[level]
	next_ball_id += 1
	board.balls.append({"id": next_ball_id, "x": clampf(x, radius, WIDTH - radius), "y": 42.0, "vx": 0.0, "vy": 0.0, "level": level, "age": 0.0})
	board.cooldown = 0.55
	board.next = board.following
	board.following = board.rng.randi_range(0, 4)

func tick(delta: float) -> void:
	time += delta
	for id: String in boards:
		var board: Dictionary = boards[id]
		if board.over:
			continue
		board.cooldown = maxf(0.0, board.cooldown - delta)
		for ball: Dictionary in board.balls:
			ball.age += delta
			ball.vy = minf(ball.vy + 1100.0 * delta, 900.0)
			ball.x += ball.vx * delta
			ball.y += ball.vy * delta
			ball.vx *= 0.995
		for iteration: int in range(6):
			_solve(board)
		var danger: bool = false
		for ball: Dictionary in board.balls:
			if ball.age > 1.4 and ball.y - RADII[ball.level] < LIMIT:
				danger = true
		board.danger = board.danger + delta if danger else 0.0
		if board.danger >= 2.0:
			board.over = true

func _solve(board: Dictionary) -> void:
	var balls: Array = board.balls
	var removed: Dictionary[int, bool] = {}
	var created: Array[Dictionary] = []
	for i: int in range(balls.size()):
		if removed.has(i):
			continue
		var a: Dictionary = balls[i]
		for j: int in range(i + 1, balls.size()):
			if removed.has(j):
				continue
			var b: Dictionary = balls[j]
			var offset: Vector2 = Vector2(b.x - a.x, b.y - a.y)
			var distance: float = offset.length()
			var reach: float = RADII[a.level] + RADII[b.level]
			if distance >= reach:
				continue
			if a.level == b.level and a.level < RADII.size() - 1:
				var level: int = a.level + 1
				removed[i] = true
				removed[j] = true
				next_ball_id += 1
				created.append({"id": next_ball_id, "x": (a.x + b.x) * 0.5, "y": (a.y + b.y) * 0.5,
					"vx": (a.vx + b.vx) * 0.5, "vy": (a.vy + b.vy) * 0.5, "level": level, "age": minf(a.age, b.age)})
				board.score += (level + 1) * (level + 2) / 2
				board.best = maxi(board.best, level)
				break
			var normal: Vector2 = offset / distance if distance > 0.001 else Vector2.RIGHT
			var mass_a: float = RADII[a.level] * RADII[a.level]
			var mass_b: float = RADII[b.level] * RADII[b.level]
			var weight: float = mass_b / (mass_a + mass_b)
			var correction: Vector2 = normal * (reach - distance)
			a.x -= correction.x * weight
			a.y -= correction.y * weight
			b.x += correction.x * (1.0 - weight)
			b.y += correction.y * (1.0 - weight)
			var speed: float = Vector2(b.vx - a.vx, b.vy - a.vy).dot(normal)
			if speed < 0.0:
				var impulse: Vector2 = normal * speed * 1.12
				a.vx += impulse.x * weight
				a.vy += impulse.y * weight
				b.vx -= impulse.x * (1.0 - weight)
				b.vy -= impulse.y * (1.0 - weight)
	for i: int in range(balls.size() - 1, -1, -1):
		if removed.has(i):
			balls.remove_at(i)
	balls.append_array(created)
	for ball: Dictionary in balls:
		var radius: float = RADII[ball.level]
		if ball.x < radius or ball.x > WIDTH - radius:
			ball.x = clampf(ball.x, radius, WIDTH - radius)
			ball.vx *= -0.12
		if ball.y > HEIGHT - radius:
			ball.y = HEIGHT - radius
			ball.vy = -absf(ball.vy) * 0.08
			ball.vx *= 0.9

func withdraw(id: String) -> void:
	boards[id].withdrawn = true
	boards[id].over = true

func complete() -> bool:
	if time >= duration:
		return true
	for id: String in boards:
		if not boards[id].over:
			return false
	return true

func snapshot() -> Dictionary:
	var result: Dictionary = {"boards": {}, "time": time, "duration": duration}
	for id: String in boards:
		var board: Dictionary = boards[id].duplicate(true)
		board.erase("rng")
		result.boards[id] = board
	return result

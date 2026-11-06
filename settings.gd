extends RefCounted
static func schema() -> Dictionary:
	return {
		"schema_format": 3, "settings_version": 1,
		"fields": {
			"duration": {"type": "int", "default": 180, "title": "比赛时限（秒）", "audience": "room", "apply": "next_round", "min": 30, "max": 600, "control": "number"},
			"merge_drop": {"type": "array", "action": "merge_drop", "default": [{"kind": "mouse", "code": 1}, {"kind": "key", "code": 32, "physical": true}], "title": "落球", "audience": "local", "apply": "immediate", "control": "binding", "items": {"type": "object", "format": "binding"}, "max_items": 2}
		},
		"layout": [{"id": "rules", "title": "游戏规则", "children": [{"field": "duration"}]}, {"id": "input", "title": "操作", "children": [{"field": "merge_drop"}]}]
	}

extends RefCounted
func check_request(request: Dictionary) -> Dictionary:
	if request.get("mode") != "standard":
		return {"ok": false, "code": "unsupported_mode", "message": "合成大西八仅支持普通排名局。"}
	return {"ok": true}

func make_config(request: Dictionary) -> Dictionary:
	return request.duplicate(true)

func map_result(result: Dictionary, _request: Dictionary) -> Dictionary:
	return result.duplicate(true)

extends Node

signal sync_completed(success: bool)

const REQUEST_TIMEOUT_SEC := 20.0

var _http: HTTPRequest
var _queue: Array = []
var _busy := false
var _auth_busy := false
var last_sync_error: String = ""
var last_sync_url: String = ""


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = REQUEST_TIMEOUT_SEC
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func is_enabled() -> bool:
	return bool(DataLoader.backend_config.get("enabled", false))


func is_configured() -> bool:
	return not _supabase_url().is_empty() and not _anon_key().is_empty()


func uses_server_dailies() -> bool:
	return is_enabled() and is_configured() and not GameState.display_name.strip_edges().is_empty()


func is_syncing() -> bool:
	return _busy or _auth_busy


func has_session() -> bool:
	return not GameState.supabase_access_token.strip_edges().is_empty()


func ensure_auth(callback: Callable = Callable()) -> void:
	if not uses_server_dailies() and not is_enabled():
		if callback.is_valid():
			callback.call(false)
		return
	if not is_configured():
		last_sync_error = "Supabase URL and anon key required"
		if callback.is_valid():
			callback.call(false)
		return
	if has_session():
		if callback.is_valid():
			callback.call(true)
		return
	if _auth_busy:
		call_deferred("_run_auth_callback", callback, false)
		return
	if not GameState.supabase_refresh_token.strip_edges().is_empty():
		_refresh_session(callback)
		return
	_sign_in_anonymous(callback)


func request_sync(callback: Callable = Callable()) -> void:
	_enqueue("status", {}, callback)


func claim_pack(callback: Callable) -> void:
	_enqueue("claim_pack", {}, callback)


func record_battle_win(callback: Callable = Callable()) -> void:
	_enqueue("record_battle_win", {}, callback)


func complete_ritual(ritual_id: String, callback: Callable) -> void:
	_enqueue("complete_ritual", {"ritual_id": ritual_id}, callback)


func ping_health(callback: Callable = Callable()) -> void:
	if not is_configured():
		callback.call({"ok": false, "error": "Supabase not configured"})
		return
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT_SEC
	add_child(http)
	var url := "%s/auth/v1/health" % _supabase_url()
	http.request_completed.connect(func(result: int, response_code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		var ok := result == HTTPRequest.RESULT_SUCCESS and response_code == 200
		callback.call({
			"ok": ok,
			"status": response_code,
			"body": body.get_string_from_utf8(),
			"error": "Network error" if result != HTTPRequest.RESULT_SUCCESS else "HTTP %d" % response_code,
		})
	)
	var headers := _api_headers("")
	http.request(url, headers, HTTPClient.METHOD_GET)


func force_offline() -> void:
	last_sync_error = "Forced offline (dev)"
	GameState.set_daily_server_offline()
	sync_completed.emit(false)


func _enqueue(action: String, extra: Dictionary, callback: Callable) -> void:
	if not uses_server_dailies():
		var offline := {"ok": false, "offline": true, "error": "Cloud dailies disabled"}
		if callback.is_valid():
			callback.call(offline)
		return
	_queue.append({
		"action": action,
		"extra": extra,
		"callback": callback,
	})
	if has_session():
		_pump_queue()
	else:
		ensure_auth(func(ok: bool) -> void:
			if ok:
				_pump_queue()
			else:
				_fail_queued_jobs(str(last_sync_error) if not last_sync_error.is_empty() else "Not signed in")
		)


func _fail_queued_jobs(message: String) -> void:
	while not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		var cb: Callable = job.get("callback", Callable())
		if cb.is_valid():
			cb.call({"ok": false, "offline": true, "error": message})
		if str(job.get("action", "")) == "status":
			GameState.set_daily_server_offline()
			last_sync_error = message
			sync_completed.emit(false)


func _pump_queue() -> void:
	if _busy or _auth_busy or _queue.is_empty():
		return
	if not has_session():
		return
	var job: Dictionary = _queue.pop_front()
	_busy = true
	var action := str(job.get("action", "status"))
	var extra: Dictionary = job.get("extra", {})
	var body := {"action": action}
	for key in extra:
		body[key] = extra[key]
	var url := "%s/functions/v1/daily" % _supabase_url()
	last_sync_url = url
	var payload := JSON.stringify(body)
	var headers := _api_headers(GameState.supabase_access_token)
	headers.append("X-Display-Name: %s" % GameState.display_name.strip_edges())
	job["_callback"] = job.get("callback", Callable())
	_http.set_meta("job", job)
	var request_err := _http.request(url, headers, HTTPClient.METHOD_POST, payload)
	if request_err != OK:
		_finish_job(job, {
			"ok": false,
			"offline": true,
			"error": "Could not start request to %s (%s)" % [url, error_string(request_err)],
		})


func _sign_in_anonymous(callback: Callable) -> void:
	_auth_busy = true
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT_SEC
	add_child(http)
	var url := "%s/auth/v1/signup" % _supabase_url()
	var headers := _api_headers("")
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		_auth_busy = false
		var parsed := _parse_json(body)
		if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
			last_sync_error = _auth_error_message(parsed, code, body.get_string_from_utf8())
			if callback.is_valid():
				callback.call(false)
			return
		_apply_auth_response(parsed)
		if callback.is_valid():
			callback.call(true)
	)
	http.request(url, headers, HTTPClient.METHOD_POST, "{}")


func _refresh_session(callback: Callable) -> void:
	_auth_busy = true
	var http := HTTPRequest.new()
	http.timeout = REQUEST_TIMEOUT_SEC
	add_child(http)
	var url := "%s/auth/v1/token?grant_type=refresh_token" % _supabase_url()
	var headers := _api_headers("")
	var payload := JSON.stringify({
		"refresh_token": GameState.supabase_refresh_token.strip_edges(),
	})
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		_auth_busy = false
		var parsed := _parse_json(body)
		if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
			GameState.clear_supabase_session()
			_sign_in_anonymous(callback)
			return
		_apply_auth_response(parsed)
		if callback.is_valid():
			callback.call(true)
	)
	http.request(url, headers, HTTPClient.METHOD_POST, payload)


func _apply_auth_response(parsed: Dictionary) -> void:
	var access := str(parsed.get("access_token", ""))
	var refresh := str(parsed.get("refresh_token", ""))
	var user: Dictionary = parsed.get("user", {})
	var user_id := str(user.get("id", ""))
	GameState.apply_supabase_session(access, refresh, user_id)
	last_sync_error = ""


func _on_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray,
) -> void:
	var job: Dictionary = _http.get_meta("job") if _http.has_meta("job") else {}
	_http.remove_meta("job")
	var text := body.get_string_from_utf8()
	var parsed := _parse_json(body)

	if response_code == 401 and not GameState.supabase_refresh_token.is_empty():
		_busy = false
		GameState.supabase_access_token = ""
		ensure_auth(func(ok: bool) -> void:
			if ok:
				_queue.push_front(job)
				_pump_queue()
			else:
				_finish_job(job, {"ok": false, "offline": true, "error": last_sync_error})
		)
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		_finish_job(job, {
			"ok": false,
			"offline": true,
			"error": _describe_http_result(result, last_sync_url),
		})
		return

	if response_code >= 200 and response_code < 300:
		if str(job.get("action", "")) == "status":
			if not parsed.has("daily_day"):
				_finish_job(job, {
					"ok": false,
					"error": "Invalid response (missing daily_day): %s" % text.substr(0, 160),
				})
				return
			GameState.apply_daily_server_state(parsed)
			last_sync_error = ""
			sync_completed.emit(true)
			_finish_job(job, parsed)
			return
		if not parsed.has("ok"):
			parsed["ok"] = true
		if parsed.has("daily_day"):
			GameState.apply_daily_server_state(parsed)
		_finish_job(job, parsed)
		return

	_finish_job(job, {
		"ok": false,
		"offline": response_code == 0,
		"status": response_code,
		"error": _format_http_error(parsed, response_code, text),
	})


func _finish_job(job: Dictionary, result: Dictionary) -> void:
	_busy = false
	var callback: Callable = job.get("_callback", Callable())
	if callback.is_valid():
		callback.call(result)
	if str(job.get("action", "")) == "status" and not result.get("ok", false):
		GameState.set_daily_server_offline()
		last_sync_error = str(result.get("error", "Could not reach cloud"))
		sync_completed.emit(false)
	_pump_queue()


func _api_headers(access_token: String) -> PackedStringArray:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: %s" % _anon_key(),
	])
	var token := access_token.strip_edges()
	if token.is_empty():
		headers.append("Authorization: Bearer %s" % _anon_key())
	else:
		headers.append("Authorization: Bearer %s" % token)
	return headers


func _supabase_url() -> String:
	var url := str(DataLoader.backend_config.get("supabase_url", "")).strip_edges()
	while url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	return url


func _anon_key() -> String:
	return str(DataLoader.backend_config.get("supabase_anon_key", "")).strip_edges()


func _parse_json(body: PackedByteArray) -> Dictionary:
	var text := body.get_string_from_utf8()
	if text.is_empty():
		return {}
	var json: Variant = JSON.parse_string(text)
	if json is Dictionary:
		return json
	return {}


func _auth_error_message(parsed: Dictionary, code: int, raw: String) -> String:
	var msg := str(parsed.get("msg", parsed.get("error_description", parsed.get("error", "")))).strip_edges()
	if msg.is_empty():
		msg = raw.substr(0, 200) if not raw.is_empty() else "HTTP %d" % code
	if msg.contains("anonymous") or code == 422:
		return "%s — enable Anonymous sign-ins in Supabase Auth settings" % msg
	return msg


func _describe_http_result(result: int, url: String) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to %s" % url
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve %s" % url
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error reaching %s" % url
		HTTPRequest.RESULT_TIMEOUT:
			return "Timed out reaching %s" % url
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS error for %s" % url
		_:
			return "Network error (%d) reaching %s" % [result, url]


func _format_http_error(parsed: Dictionary, response_code: int, body_text: String) -> String:
	var detail: Variant = parsed.get("error", parsed.get("detail", ""))
	if detail is Dictionary:
		detail = str(detail.get("message", detail))
	var message := str(detail).strip_edges()
	if message.is_empty():
		var trimmed := body_text.strip_edges()
		if trimmed.is_empty():
			return "HTTP %d" % response_code
		return "HTTP %d: %s" % [response_code, trimmed.substr(0, 160)]
	return "HTTP %d: %s" % [response_code, message]


func _run_auth_callback(callback: Callable, ok: bool) -> void:
	if callback.is_valid():
		callback.call(ok)

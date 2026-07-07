extends Node

signal connection_changed(online: bool)

var online := false
var status_message := ""


func requires_online() -> bool:
	if not bool(DataLoader.backend_config.get("require_online", true)):
		return false
	return DailyBackend.is_configured()


func can_play() -> bool:
	if not requires_online():
		return true
	if not DailyBackend.is_enabled():
		status_message = "Cloud play is disabled in config."
		return false
	if GameState.needs_profile_setup():
		return online
	return online and GameState.daily_server_online


func refresh(callback: Callable = Callable()) -> void:
	if not requires_online():
		_set_online(true, "")
		if callback.is_valid():
			callback.call(true)
		return

	if not DailyBackend.is_configured():
		_set_online(false, "Supabase URL and anon key are not configured.")
		if callback.is_valid():
			callback.call(false)
		return

	if not DailyBackend.is_enabled():
		_set_online(false, "Cloud play is disabled. Set enabled: true in backend config.")
		if callback.is_valid():
			callback.call(false)
		return

	DailyBackend.ping_health(func(ping_result: Dictionary) -> void:
		if not ping_result.get("ok", false):
			var ping_err := str(ping_result.get("error", "")).strip_edges()
			var msg := "Cannot reach Supabase. Check your internet connection."
			if not ping_err.is_empty():
				msg = ping_err
			_set_online(false, msg)
			if callback.is_valid():
				callback.call(false)
			return

		if GameState.needs_profile_setup():
			_set_online(true, "")
			if callback.is_valid():
				callback.call(true)
			return

		DailyBackend.ensure_auth(func(auth_ok: bool) -> void:
			if not auth_ok:
				_set_online(false, DailyBackend.last_sync_error)
				if callback.is_valid():
					callback.call(false)
				return
			DailyBackend.request_sync(func(sync_result: Dictionary) -> void:
				var ok: bool = bool(sync_result.get("ok", false)) and GameState.daily_server_online
				var msg := "" if ok else str(sync_result.get("error", DailyBackend.last_sync_error))
				_set_online(ok, msg)
				if callback.is_valid():
					callback.call(ok)
			)
		)
	)


func _set_online(is_online: bool, message: String) -> void:
	online = is_online
	status_message = message
	connection_changed.emit(online)

extends Node

const SAVE_PATH := "user://save.json"

var _session_ready := false


func begin_session() -> void:
	_session_ready = false


func save_game() -> void:
	if not _session_ready:
		push_warning("SaveManager: ignored save before session loaded")
		return
	if not GameState.can_persist():
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not save game")
		return
	file.store_string(JSON.stringify(GameState.to_save_dict(), "\t"))


func load_game() -> bool:
	_session_ready = true
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not parsed is Dictionary:
		return false
	GameState.from_save_dict(parsed)
	return true


func reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("save.json")
	_session_ready = true
	GameState.reset_for_fresh_install()

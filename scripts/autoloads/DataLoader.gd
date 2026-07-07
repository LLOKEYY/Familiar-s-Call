extends Node

var familiars: Dictionary = {}
var synergy_config: Dictionary = {}
var economy_config: Dictionary = {}
var rift_trials: Array = []
var battle_pass_config: Dictionary = {}
var daily_rituals_config: Dictionary = {}
var familiar_levels_config: Dictionary = {}
var backend_config: Dictionary = {}

signal backend_dev_config_changed


const DEV_BACKEND_PATH := "user://dev_backend.json"


func _ready() -> void:
	load_all()


func load_all() -> void:
	_load_familiars()
	synergy_config = _load_json("res://data/synergy_bonuses.json")
	economy_config = _load_json("res://data/economy_config.json")
	var trials_data: Dictionary = _load_json("res://data/rift_trials.json")
	rift_trials = trials_data.get("trials", [])
	battle_pass_config = _load_json("res://data/battle_pass.json")
	daily_rituals_config = _load_json("res://data/daily_rituals.json")
	familiar_levels_config = _load_json("res://data/familiar_levels.json")
	backend_config = _load_json("res://data/backend_config.json")
	_merge_dev_backend_config()


func set_dev_backend_enabled(enabled: bool) -> void:
	backend_config["enabled"] = enabled
	_persist_dev_backend({"enabled": enabled})
	backend_dev_config_changed.emit()


func set_dev_supabase_url(url: String) -> void:
	var trimmed := normalize_supabase_url(url)
	if trimmed.is_empty():
		return
	backend_config["supabase_url"] = trimmed
	_persist_dev_backend({"supabase_url": trimmed})
	backend_dev_config_changed.emit()


func set_dev_supabase_anon_key(key: String) -> void:
	var trimmed := key.strip_edges()
	if trimmed.is_empty():
		return
	backend_config["supabase_anon_key"] = trimmed
	_persist_dev_backend({"supabase_anon_key": trimmed})
	backend_dev_config_changed.emit()


func reset_dev_backend_overrides() -> void:
	if FileAccess.file_exists(DEV_BACKEND_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(DEV_BACKEND_PATH))
	backend_config = _load_json("res://data/backend_config.json")
	backend_dev_config_changed.emit()


func _merge_dev_backend_config() -> void:
	var dev := _load_user_json(DEV_BACKEND_PATH)
	if dev.is_empty():
		return
	if dev.has("enabled"):
		backend_config["enabled"] = bool(dev["enabled"])
	if dev.has("require_online"):
		backend_config["require_online"] = bool(dev["require_online"])
	if dev.has("supabase_url"):
		var url := normalize_supabase_url(str(dev["supabase_url"]))
		if not url.is_empty():
			backend_config["supabase_url"] = url
	if dev.has("supabase_anon_key"):
		var key := str(dev["supabase_anon_key"]).strip_edges()
		if not key.is_empty():
			backend_config["supabase_anon_key"] = key


func _persist_dev_backend(patch: Dictionary) -> void:
	var dev := _load_user_json(DEV_BACKEND_PATH)
	for key in patch:
		dev[key] = patch[key]
	_save_user_json(DEV_BACKEND_PATH, dev)


func _load_user_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	return {}


func _save_user_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Failed to write: %s" % path)
		return
	file.store_string(JSON.stringify(data, "\t"))


func normalize_supabase_url(url: String) -> String:
	var trimmed := url.strip_edges()
	while trimmed.ends_with("/"):
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	if trimmed.ends_with("/rest/v1"):
		trimmed = trimmed.substr(0, trimmed.length() - "/rest/v1".length())
		while trimmed.ends_with("/"):
			trimmed = trimmed.substr(0, trimmed.length() - 1)
	if not trimmed.is_empty() and not trimmed.begins_with("http://") and not trimmed.begins_with("https://"):
		trimmed = "https://%s" % trimmed
	return trimmed


func _load_familiars() -> void:
	var data: Dictionary = _load_json("res://data/familiars.json")
	familiars.clear()
	for entry in data.get("familiars", []):
		var familiar := FamiliarData.from_dict(entry)
		familiars[familiar.id] = familiar


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to load: %s" % path)
		return {}
	var text := file.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	return {}


func get_familiar(id: String) -> FamiliarData:
	return familiars.get(id)


func get_all_familiars() -> Array:
	return familiars.values()


func get_familiars_by_school(school: String) -> Array:
	var result: Array = []
	for f in familiars.values():
		if f.school == school:
			result.append(f)
	return result


func get_familiars_by_rarity(rarity: String) -> Array:
	var result: Array = []
	for f in familiars.values():
		if f.rarity == rarity:
			result.append(f)
	return result

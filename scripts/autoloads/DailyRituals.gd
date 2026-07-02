extends Node

const SCHOOL_RITUAL_BY_SCHOOL := {
	"pyromancy": "win_field_pyromancy",
	"nature": "win_field_nature",
	"necromancy": "win_field_necromancy",
	"illusion": "win_field_illusion",
	"military": "win_field_military",
}


func _ready() -> void:
	ensure_today()


func ensure_today() -> void:
	if DailyBackend.uses_server_dailies():
		DailyBackend.request_sync()
		return
	_ensure_today_local()


func get_display_list() -> Array:
	if DailyBackend.uses_server_dailies() and not GameState.daily_server_online:
		return _display_list_from_cache()
	if not DailyBackend.uses_server_dailies():
		_ensure_today_local()
	var reward := dust_reward()
	var result: Array = []
	for ritual_id in GameState.daily_ritual_ids:
		var id: String = str(ritual_id)
		var done: bool = GameState.daily_ritual_completed.get(id, false)
		result.append({
			"id": id,
			"label": get_label(id),
			"completed": done,
			"reward": reward,
		})
	return result


func get_summary() -> Dictionary:
	var list := get_display_list()
	var completed := 0
	for entry in list:
		if entry.get("completed", false):
			completed += 1
	return {
		"rituals": list,
		"completed": completed,
		"total": mini(3, list.size()),
		"dust_reward": dust_reward(),
		"server_online": GameState.daily_server_online if DailyBackend.uses_server_dailies() else true,
	}


func dust_reward() -> int:
	var eco := int(DataLoader.economy_config.get("daily_ritual_dust_reward", 0))
	if eco > 0:
		return eco
	return int(DataLoader.daily_rituals_config.get("dust_reward", 150))


func get_label(ritual_id: String) -> String:
	var rituals: Dictionary = DataLoader.daily_rituals_config.get("rituals", {})
	var entry: Dictionary = rituals.get(ritual_id, {})
	return str(entry.get("label", ritual_id))


func on_battle_won(battle_data: Dictionary, pending: Dictionary) -> void:
	if DailyBackend.uses_server_dailies():
		if not GameState.daily_rewards_available():
			return
		DailyBackend.record_battle_win(func(_result: Dictionary) -> void:
			_try_completes_from_battle(battle_data, pending)
		)
		return
	_ensure_today_local()
	_try_completes_from_battle(battle_data, pending)


func on_pack_opened() -> void:
	_try_complete("open_page", true)


func on_familiar_leveled() -> void:
	_try_complete("level_up_familiar", true)


func record_clash_ticket_used() -> void:
	_try_complete("use_clash_ticket", true)


func _try_completes_from_battle(battle_data: Dictionary, pending: Dictionary) -> void:
	var stats: Dictionary = battle_data.get("ritual_stats", {})
	var schools: Dictionary = stats.get("schools_fielded", {})

	_try_complete("win_2_battles", GameState.daily_battle_wins >= 2)
	_try_complete("win_taunt_familiar", stats.get("had_taunt_familiar", false))
	_try_complete("win_no_losses", int(stats.get("player_deaths", 0)) == 0)
	_try_complete("win_dual_synergy", stats.get("had_dual_synergy", false))
	_try_complete("win_with_burn", stats.get("used_burn", false))
	_try_complete("win_heal_lifesteal", stats.get("used_heal_or_lifesteal", false))
	_try_complete("win_death_trigger", stats.get("enemy_death_trigger_kill", false))

	for school in SCHOOL_RITUAL_BY_SCHOOL:
		var ritual_id: String = SCHOOL_RITUAL_BY_SCHOOL[school]
		_try_complete(ritual_id, schools.get(school, false))

	if pending.get("mode", "") == "clash":
		_try_complete("win_clash", true)


func _ensure_today_local() -> void:
	var today := _today_key_utc()
	if GameState.daily_ritual_date == today:
		if GameState.daily_ritual_ids.size() == 3:
			return
		GameState.daily_ritual_ids = _pick_today_rituals(today)
		GameState.daily_ritual_completed = {}
		_emit_rituals_changed()
		SaveManager.save_game()
		return
	_roll_new_day_local(today)


func _roll_new_day_local(today: String) -> void:
	GameState.daily_ritual_date = today
	GameState.daily_cache_day = today
	GameState.daily_ritual_ids = _pick_today_rituals(today)
	GameState.daily_ritual_completed = {}
	GameState.daily_battle_wins = 0
	GameState.daily_pack_opened = false
	GameState.daily_free_page_claimed = false
	_emit_rituals_changed()
	SaveManager.save_game()


func _pick_today_rituals(today: String) -> Array:
	var cfg: Dictionary = DataLoader.daily_rituals_config
	var easy: String = str(cfg.get("easy_ritual", "win_2_battles"))
	var school_entry: Dictionary = _school_entry_for_day(today)
	var school_id: String = str(school_entry.get("id", "win_field_pyromancy"))

	var varied_pool: Array = cfg.get("varied_pool", []).duplicate()
	for remove_id in [easy, school_id]:
		varied_pool.erase(remove_id)
	for entry in cfg.get("school_rotation", []):
		if entry is Dictionary:
			varied_pool.erase(str(entry.get("id", "")))

	var varied_id := easy
	if not varied_pool.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(today + ":varied")
		varied_id = str(varied_pool[rng.randi() % varied_pool.size()])

	return [easy, school_id, varied_id]


func _school_entry_for_day(today: String) -> Dictionary:
	var rotation: Array = DataLoader.daily_rituals_config.get("school_rotation", [])
	if rotation.is_empty():
		return {}
	var parts: PackedStringArray = today.split("-")
	if parts.size() != 3:
		return {}
	var index := (int(parts[0]) * 372 + int(parts[1]) * 31 + int(parts[2])) % rotation.size()
	var entry = rotation[index]
	if entry is Dictionary:
		return entry
	return {}


func _try_complete(ritual_id: String, condition: bool) -> void:
	if not condition:
		return
	if ritual_id not in GameState.daily_ritual_ids:
		return
	if GameState.daily_ritual_completed.get(ritual_id, false):
		return
	if DailyBackend.uses_server_dailies():
		if not GameState.daily_rewards_available():
			return
		DailyBackend.complete_ritual(ritual_id, func(result: Dictionary) -> void:
			if not result.get("ok", false):
				return
			var dust := int(result.get("dust_granted", dust_reward()))
			if dust > 0:
				GameState.grant_dust(dust)
				SaveManager.save_game()
		)
		return
	GameState.daily_ritual_completed[ritual_id] = true
	GameState.grant_dust(dust_reward())
	_emit_rituals_changed()
	SaveManager.save_game()


func _display_list_from_cache() -> Array:
	var reward := dust_reward()
	var result: Array = []
	for ritual_id in GameState.daily_ritual_ids:
		var id: String = str(ritual_id)
		result.append({
			"id": id,
			"label": get_label(id),
			"completed": GameState.daily_ritual_completed.get(id, false),
			"reward": reward,
		})
	return result


func _today_key_utc() -> String:
	return Time.get_date_string_from_system(true)


func _emit_rituals_changed() -> void:
	call_deferred("_do_emit_rituals_changed")


func _do_emit_rituals_changed() -> void:
	GameState.rituals_changed.emit()

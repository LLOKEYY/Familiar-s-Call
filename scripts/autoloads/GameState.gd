extends Node

signal currencies_changed
signal collection_changed
signal squad_changed
signal battle_pass_changed
signal settings_changed
signal rituals_changed
signal profile_changed

const DISPLAY_NAME_MIN := 3
const DISPLAY_NAME_MAX := 16

var profile_id: String = ""
var display_name: String = ""
var supabase_access_token: String = ""
var supabase_refresh_token: String = ""
var supabase_user_id: String = ""

var dust: int = 0
var lumen: int = 0

var owned_familiars: Dictionary = {}
var active_coven: Array = []
var defense_coven: Array = []

var grimoire_pages: Dictionary = {}
var familiar_levels: Dictionary = {}
var bound_pages: Dictionary = {}
var grimoire_completion: Dictionary = {}

var cleared_trials: Array = []
var daily_free_page_claimed: bool = false
var daily_battle_wins: int = 0
var daily_pack_opened: bool = false
var daily_ritual_date: String = ""
var daily_ritual_ids: Array = []
var daily_ritual_completed: Dictionary = {}
var daily_cache_day: String = ""
var daily_server_online: bool = false
var daily_server_time_utc: String = ""
var tome_pity_counter: int = 0
var recent_pulls: Array = []

var pending_battle: Dictionary = {}
var last_battle_result: Dictionary = {}
var pending_daily_page_open: bool = false

var battle_pass_xp: int = 0
var battle_pass_premium: bool = false
var battle_pass_claimed_free: Dictionary = {}
var battle_pass_claimed_premium: Dictionary = {}

var music_volume: int = 80
var sfx_volume: int = 80
var vibration_enabled: bool = true
var default_battle_speed_index: int = 0
var reduced_motion: bool = false
var notify_daily_page: bool = true
var notify_clash_digest: bool = true


func _ready() -> void:
	SaveManager.begin_session()
	SaveManager.load_game()


func needs_profile_setup() -> bool:
	return display_name.strip_edges().is_empty()


func can_persist() -> bool:
	return not needs_profile_setup()


func validate_display_name(name: String) -> Dictionary:
	var trimmed := name.strip_edges()
	if trimmed.length() < DISPLAY_NAME_MIN:
		return {"ok": false, "message": "Use at least 3 characters."}
	if trimmed.length() > DISPLAY_NAME_MAX:
		return {"ok": false, "message": "Max %d characters." % DISPLAY_NAME_MAX}
	for i in trimmed.length():
		if trimmed.unicode_at(i) < 32:
			return {"ok": false, "message": "Name contains invalid characters."}
	return {"ok": true, "name": trimmed}


func setup_profile(name: String) -> Dictionary:
	var check := validate_display_name(name)
	if not check.get("ok", false):
		return check
	if profile_id.is_empty():
		profile_id = _generate_profile_id()
	display_name = str(check.get("name", ""))
	var fresh_game := grimoire_pages.is_empty() and owned_familiars.is_empty()
	if fresh_game:
		_init_new_game()
	else:
		SaveManager.save_game()
	profile_changed.emit()
	if DailyBackend.is_enabled() and DailyBackend.is_configured():
		DailyBackend.ensure_auth()
	return {"ok": true, "message": ""}


func update_display_name(name: String) -> Dictionary:
	if needs_profile_setup():
		return setup_profile(name)
	var check := validate_display_name(name)
	if not check.get("ok", false):
		return check
	display_name = str(check.get("name", ""))
	SaveManager.save_game()
	profile_changed.emit()
	return {"ok": true, "message": ""}


func reset_for_fresh_install() -> void:
	profile_id = ""
	display_name = ""
	clear_supabase_session()
	dust = 0
	lumen = 0
	owned_familiars = {}
	active_coven = []
	defense_coven = []
	grimoire_pages = {}
	familiar_levels = {}
	bound_pages = {}
	grimoire_completion = {}
	cleared_trials = []
	daily_free_page_claimed = false
	daily_battle_wins = 0
	daily_pack_opened = false
	daily_ritual_date = ""
	daily_ritual_ids = []
	daily_ritual_completed = {}
	daily_cache_day = ""
	daily_server_online = false
	daily_server_time_utc = ""
	tome_pity_counter = 0
	recent_pulls = []
	pending_battle = {}
	last_battle_result = {}
	pending_daily_page_open = false
	battle_pass_xp = 0
	battle_pass_premium = false
	battle_pass_claimed_free = {}
	battle_pass_claimed_premium = {}
	music_volume = 80
	sfx_volume = 80
	vibration_enabled = true
	default_battle_speed_index = 0
	reduced_motion = false
	notify_daily_page = true
	notify_clash_digest = true


func _generate_profile_id() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(16).hex_encode()


func _init_new_game() -> void:
	var eco: Dictionary = DataLoader.economy_config
	dust = int(eco.get("starting_dust", 600))
	lumen = int(eco.get("starting_lumen", 50))

	var starters := [
		"ember_pup", "mosshollow_sprite", "bonewisp", "mirage_kit", "scrap_sentinel",
		"flareling", "fernling", "grimrat", "echo_sprite", "rookie_trooper",
	]
	for id in starters:
		add_familiar(id)

	active_coven = [
		{"id": "ember_pup", "row": "front"},
		{"id": "scrap_sentinel", "row": "front"},
		{"id": "mosshollow_sprite", "row": "front"},
		{"id": "bonewisp", "row": "back"},
		{"id": "mirage_kit", "row": "back"},
		{"id": "flareling", "row": "back"},
	]
	defense_coven = active_coven.duplicate(true)
	SaveManager.save_game()


func add_familiar(id: String) -> Dictionary:
	var result := {
		"new_unlock": false,
		"level_up": false,
		"new_level": 0,
		"dust_granted": 0,
		"max_level_dupe": false,
	}
	var had_pages := int(grimoire_pages.get(id, 0)) > 0
	owned_familiars[id] = owned_familiars.get(id, 0) + 1

	if not had_pages:
		grimoire_pages[id] = 1
		familiar_levels[id] = 1
		result.new_unlock = true
		result.new_level = 1
		_update_school_completion(id)
		collection_changed.emit()
		return result

	var old_level := get_familiar_level(id)
	if old_level >= FamiliarLeveling.max_level():
		var data: FamiliarData = DataLoader.get_familiar(id)
		var dust := FamiliarLeveling.dust_for_dupe(data.rarity if data else "common")
		grant_dust(dust)
		result.dust_granted = dust
		result.max_level_dupe = true
		result.new_level = old_level
		collection_changed.emit()
		return result

	grimoire_pages[id] = int(grimoire_pages.get(id, 0)) + 1
	var new_level := FamiliarLeveling.level_from_total_pages(int(grimoire_pages[id]))
	familiar_levels[id] = new_level
	result.new_level = new_level
	if new_level > old_level:
		result.level_up = true
		DailyRituals.on_familiar_leveled()

	_update_school_completion(id)
	collection_changed.emit()
	return result


func get_familiar_level(id: String) -> int:
	if int(grimoire_pages.get(id, 0)) <= 0:
		return 0
	if familiar_levels.has(id):
		return int(familiar_levels[id])
	return FamiliarLeveling.level_from_total_pages(int(grimoire_pages[id]))


func owns_familiar(id: String) -> bool:
	return owned_familiars.get(id, 0) > 0


func get_owned_list() -> Array:
	var ids: Dictionary = {}
	for id in owned_familiars:
		ids[str(id)] = true
	for id in grimoire_pages:
		if int(grimoire_pages.get(id, 0)) > 0:
			ids[str(id)] = true

	var result: Array = []
	for id in ids:
		var data: FamiliarData = DataLoader.get_familiar(id)
		if data == null:
			continue
		var count: int = maxi(
			int(owned_familiars.get(id, 0)),
			int(grimoire_pages.get(id, 0))
		)
		if count <= 0:
			count = 1
		result.append({
			"data": data,
			"count": count,
			"level": get_familiar_level(id),
		})
	result.sort_custom(func(a, b): return a.data.display_name < b.data.display_name)
	return result


func grant_dust(amount: int) -> void:
	dust += amount
	currencies_changed.emit()


func grant_lumen(amount: int) -> void:
	lumen += amount
	currencies_changed.emit()


func spend_dust(amount: int) -> bool:
	if dust < amount:
		return false
	dust -= amount
	currencies_changed.emit()
	return true


func spend_lumen(amount: int) -> bool:
	if lumen < amount:
		return false
	lumen -= amount
	currencies_changed.emit()
	return true


func set_active_coven(squad: Array) -> void:
	active_coven = squad.duplicate(true)
	squad_changed.emit()


func set_defense_coven(squad: Array) -> void:
	defense_coven = squad.duplicate(true)
	squad_changed.emit()


func record_bound_page_win(dual_key: String) -> void:
	if dual_key.is_empty():
		return
	bound_pages[dual_key] = bound_pages.get(dual_key, 0) + 1


func record_trial_clear(trial_id: String) -> void:
	if trial_id not in cleared_trials:
		cleared_trials.append(trial_id)


func is_trial_cleared(trial_id: String) -> bool:
	return trial_id in cleared_trials


func claim_daily_free_page() -> bool:
	if daily_free_page_claimed:
		return false
	daily_free_page_claimed = true
	return true


func apply_daily_server_state(data: Dictionary) -> void:
	daily_ritual_date = str(data.get("daily_day", daily_ritual_date))
	daily_cache_day = daily_ritual_date
	daily_server_time_utc = str(data.get("server_time_utc", ""))
	daily_server_online = true

	var ids: Array = []
	for ritual_id in data.get("ritual_ids", []):
		ids.append(str(ritual_id))
	if not ids.is_empty():
		daily_ritual_ids = ids

	var completed: Dictionary = data.get("ritual_completed", {})
	if completed is Dictionary:
		daily_ritual_completed = completed.duplicate()

	daily_battle_wins = int(data.get("daily_battle_wins", daily_battle_wins))
	daily_free_page_claimed = bool(data.get("pack_claimed", daily_free_page_claimed))
	daily_pack_opened = daily_free_page_claimed
	SaveManager.save_game()
	rituals_changed.emit()


func set_daily_server_offline() -> void:
	daily_server_online = false


func apply_supabase_session(access_token: String, refresh_token: String, user_id: String) -> void:
	supabase_access_token = access_token.strip_edges()
	supabase_refresh_token = refresh_token.strip_edges()
	supabase_user_id = user_id.strip_edges()
	if not supabase_user_id.is_empty():
		profile_id = supabase_user_id
	SaveManager.save_game()


func clear_supabase_session() -> void:
	supabase_access_token = ""
	supabase_refresh_token = ""
	supabase_user_id = ""


func daily_rewards_available() -> bool:
	if OnlineGate.requires_online():
		return daily_server_online
	if not DailyBackend.uses_server_dailies():
		return true
	return daily_server_online


func request_daily_page_open() -> void:
	pending_daily_page_open = true


func consume_daily_page_open_request() -> bool:
	var should_open := pending_daily_page_open
	pending_daily_page_open = false
	return should_open


func get_school_completion(school: String) -> float:
	var total := DataLoader.get_familiars_by_school(school).size()
	if total == 0:
		return 0.0
	var owned := 0
	for f in DataLoader.get_familiars_by_school(school):
		if grimoire_pages.has(f.id):
			owned += 1
	return float(owned) / float(total)


func _update_school_completion(id: String) -> void:
	var data: FamiliarData = DataLoader.get_familiar(id)
	if data == null:
		return
	grimoire_completion[data.school] = get_school_completion(data.school)


func record_battle_win() -> void:
	if not DailyBackend.uses_server_dailies():
		daily_battle_wins += 1
	add_battle_pass_xp(int(DataLoader.battle_pass_config.get("xp_per_win", 30)))
	DailyRituals.on_battle_won(last_battle_result, pending_battle)


func record_pack_opened() -> void:
	daily_pack_opened = true
	DailyRituals.on_pack_opened()


func record_recent_pull(familiar_id: String) -> void:
	if familiar_id.is_empty():
		return
	recent_pulls.insert(0, familiar_id)
	while recent_pulls.size() > 20:
		recent_pulls.pop_back()


func owns_school_familiar(school: String) -> bool:
	for id in owned_familiars:
		var data: FamiliarData = DataLoader.get_familiar(id)
		if data != null and data.school == school:
			return true
	return false


func get_daily_rituals() -> Dictionary:
	return DailyRituals.get_summary()


func add_battle_pass_xp(amount: int) -> void:
	if amount <= 0:
		return
	battle_pass_xp += amount
	battle_pass_changed.emit()


func get_battle_pass_max_tier() -> int:
	var thresholds: Array = DataLoader.battle_pass_config.get("tier_xp", [])
	return maxi(1, thresholds.size())


func get_battle_pass_tier() -> int:
	var thresholds: Array = DataLoader.battle_pass_config.get("tier_xp", [])
	var tier := 1
	for i in thresholds.size():
		if battle_pass_xp >= int(thresholds[i]):
			tier = i + 1
	return mini(tier, get_battle_pass_max_tier())


func get_battle_pass_tier_progress() -> Dictionary:
	var tier := get_battle_pass_tier()
	var thresholds: Array = DataLoader.battle_pass_config.get("tier_xp", [])
	var max_tier := get_battle_pass_max_tier()
	if tier >= max_tier:
		var last_xp := int(thresholds[max_tier - 1]) if thresholds.size() >= max_tier else 0
		return {"tier": tier, "current": battle_pass_xp - last_xp, "needed": 1, "ratio": 1.0}

	var floor_xp := int(thresholds[tier - 1]) if tier > 0 and tier - 1 < thresholds.size() else 0
	var ceil_xp := int(thresholds[tier]) if tier < thresholds.size() else floor_xp + 1
	var span := maxi(1, ceil_xp - floor_xp)
	var current := battle_pass_xp - floor_xp
	return {
		"tier": tier,
		"current": current,
		"needed": span,
		"ratio": clampf(float(current) / float(span), 0.0, 1.0),
	}


func is_battle_pass_reward_claimed(tier: int, premium: bool) -> bool:
	var key := str(tier)
	if premium:
		return battle_pass_claimed_premium.get(key, false)
	return battle_pass_claimed_free.get(key, false)


func unlock_battle_pass_premium() -> void:
	if battle_pass_premium:
		return
	battle_pass_premium = true
	battle_pass_changed.emit()


func claim_battle_pass_reward(tier: int, premium: bool) -> Dictionary:
	if tier < 1 or tier > get_battle_pass_tier():
		return {"ok": false, "error": "Tier not unlocked yet"}
	if premium and not battle_pass_premium:
		return {"ok": false, "error": "Unlock the premium track first"}
	if is_battle_pass_reward_claimed(tier, premium):
		return {"ok": false, "error": "Already claimed"}

	var reward := _battle_pass_reward_for_tier(tier, premium)
	if reward.is_empty():
		return {"ok": false, "error": "No reward configured"}

	var grant := _grant_battle_pass_reward(reward)
	if not grant.get("ok", false):
		return grant

	var key := str(tier)
	if premium:
		battle_pass_claimed_premium[key] = true
	else:
		battle_pass_claimed_free[key] = true
	battle_pass_changed.emit()
	SaveManager.save_game()
	return grant


func _battle_pass_reward_for_tier(tier: int, premium: bool) -> Dictionary:
	for entry in DataLoader.battle_pass_config.get("tiers", []):
		if int(entry.get("tier", 0)) == tier:
			var track_key := "premium" if premium else "free"
			return entry.get(track_key, {})
	return {}


func _grant_battle_pass_reward(reward: Dictionary) -> Dictionary:
	var kind: String = reward.get("type", "")
	match kind:
		"dust":
			var amount := int(reward.get("amount", 0))
			grant_dust(amount)
			return {"ok": true, "message": "+%d Dust" % amount}
		"lumen":
			var amount := int(reward.get("amount", 0))
			grant_lumen(amount)
			return {"ok": true, "message": "+%d Lumen" % amount}
		"page", "promo_card":
			var fid: String = reward.get("familiar_id", "")
			if fid.is_empty():
				return {"ok": false, "error": "Missing familiar"}
			var data: FamiliarData = DataLoader.get_familiar(fid)
			if data == null:
				return {"ok": false, "error": "Unknown familiar"}
			add_familiar(fid)
			record_recent_pull(fid)
			if kind == "promo_card":
				return {"ok": true, "message": "Season card: %s!" % data.display_name, "familiar": data}
			return {"ok": true, "message": "Page: %s" % data.display_name, "familiar": data}
	return {"ok": false, "error": "Unknown reward type"}


func save_settings() -> void:
	settings_changed.emit()
	SaveManager.save_game()


func get_default_battle_speed_multiplier() -> float:
	var speeds := [1.0, 2.0, 3.0]
	var idx := clampi(default_battle_speed_index, 0, speeds.size() - 1)
	return speeds[idx]


func to_save_dict() -> Dictionary:
	return {
		"profile_id": profile_id,
		"display_name": display_name,
		"supabase_access_token": supabase_access_token,
		"supabase_refresh_token": supabase_refresh_token,
		"supabase_user_id": supabase_user_id,
		"dust": dust,
		"lumen": lumen,
		"owned_familiars": owned_familiars.duplicate(),
		"active_coven": active_coven.duplicate(true),
		"defense_coven": defense_coven.duplicate(true),
		"grimoire_pages": grimoire_pages.duplicate(),
		"familiar_levels": familiar_levels.duplicate(),
		"bound_pages": bound_pages.duplicate(),
		"cleared_trials": cleared_trials.duplicate(),
		"daily_free_page_claimed": daily_free_page_claimed,
		"daily_battle_wins": daily_battle_wins,
		"daily_pack_opened": daily_pack_opened,
		"daily_ritual_date": daily_ritual_date,
		"daily_ritual_ids": daily_ritual_ids.duplicate(),
		"daily_ritual_completed": daily_ritual_completed.duplicate(),
		"daily_cache_day": daily_cache_day,
		"daily_server_time_utc": daily_server_time_utc,
		"tome_pity_counter": tome_pity_counter,
		"recent_pulls": recent_pulls.duplicate(),
		"battle_pass_xp": battle_pass_xp,
		"battle_pass_premium": battle_pass_premium,
		"battle_pass_claimed_free": battle_pass_claimed_free.duplicate(),
		"battle_pass_claimed_premium": battle_pass_claimed_premium.duplicate(),
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"vibration_enabled": vibration_enabled,
		"default_battle_speed_index": default_battle_speed_index,
		"reduced_motion": reduced_motion,
		"notify_daily_page": notify_daily_page,
		"notify_clash_digest": notify_clash_digest,
	}


func from_save_dict(data: Dictionary) -> void:
	profile_id = str(data.get("profile_id", ""))
	display_name = str(data.get("display_name", "")).strip_edges()
	supabase_access_token = str(data.get("supabase_access_token", ""))
	supabase_refresh_token = str(data.get("supabase_refresh_token", ""))
	supabase_user_id = str(data.get("supabase_user_id", ""))
	if not display_name.is_empty() and profile_id.is_empty():
		profile_id = _generate_profile_id()
	if not supabase_user_id.is_empty():
		profile_id = supabase_user_id
	dust = int(data.get("dust", 0))
	lumen = int(data.get("lumen", 0))
	owned_familiars = data.get("owned_familiars", {}).duplicate()
	active_coven = data.get("active_coven", []).duplicate(true)
	defense_coven = data.get("defense_coven", active_coven).duplicate(true)
	grimoire_pages = data.get("grimoire_pages", {}).duplicate()
	familiar_levels = data.get("familiar_levels", {}).duplicate()
	bound_pages = data.get("bound_pages", {}).duplicate()
	cleared_trials = data.get("cleared_trials", []).duplicate()
	daily_free_page_claimed = data.get("daily_free_page_claimed", false)
	daily_battle_wins = int(data.get("daily_battle_wins", 0))
	daily_pack_opened = data.get("daily_pack_opened", false)
	daily_ritual_date = str(data.get("daily_ritual_date", ""))
	daily_ritual_ids = data.get("daily_ritual_ids", []).duplicate()
	daily_ritual_completed = data.get("daily_ritual_completed", {}).duplicate()
	daily_cache_day = str(data.get("daily_cache_day", daily_ritual_date))
	daily_server_time_utc = str(data.get("daily_server_time_utc", ""))
	daily_server_online = false
	tome_pity_counter = int(data.get("tome_pity_counter", 0))
	recent_pulls = data.get("recent_pulls", []).duplicate()
	battle_pass_xp = int(data.get("battle_pass_xp", 0))
	battle_pass_premium = data.get("battle_pass_premium", false)
	battle_pass_claimed_free = data.get("battle_pass_claimed_free", {}).duplicate()
	battle_pass_claimed_premium = data.get("battle_pass_claimed_premium", {}).duplicate()
	music_volume = int(data.get("music_volume", 80))
	sfx_volume = int(data.get("sfx_volume", 80))
	vibration_enabled = data.get("vibration_enabled", true)
	default_battle_speed_index = int(data.get("default_battle_speed_index", 0))
	reduced_motion = data.get("reduced_motion", false)
	notify_daily_page = data.get("notify_daily_page", true)
	notify_clash_digest = data.get("notify_clash_digest", true)
	_sync_familiar_levels()
	_sync_collection_records()
	for school in ["pyromancy", "nature", "necromancy", "illusion", "military"]:
		grimoire_completion[school] = get_school_completion(school)
	collection_changed.emit()


func _sync_familiar_levels() -> void:
	for id in grimoire_pages:
		var sid := str(id)
		var pages: int = int(grimoire_pages[sid])
		if pages > 0:
			familiar_levels[sid] = FamiliarLeveling.level_from_total_pages(pages)


func _sync_collection_records() -> void:
	for id in grimoire_pages:
		var sid := str(id)
		var pages: int = int(grimoire_pages[id])
		if pages > 0 and int(owned_familiars.get(sid, 0)) < pages:
			owned_familiars[sid] = pages
	for id in owned_familiars:
		var sid := str(id)
		var owned: int = int(owned_familiars[sid])
		if owned > 0 and int(grimoire_pages.get(sid, 0)) < owned:
			grimoire_pages[sid] = owned

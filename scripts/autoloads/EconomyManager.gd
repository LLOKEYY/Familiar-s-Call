extends Node

func open_pack(pack_type: String) -> Dictionary:
	var packs: Dictionary = DataLoader.economy_config.get("packs", {})
	if not packs.has(pack_type):
		return {"ok": false, "error": "Unknown pack type"}

	var pack_cfg: Dictionary = packs[pack_type]
	var currency: String = pack_cfg.get("cost_currency", "dust")
	var cost: int = int(pack_cfg.get("cost", 0))

	if currency == "dust":
		if not GameState.spend_dust(cost):
			return {"ok": false, "error": "Not enough Dust"}
	else:
		if not GameState.spend_lumen(cost):
			return {"ok": false, "error": "Not enough Lumen"}

	var rarity: String = _roll_rarity(pack_type, pack_cfg.get("odds", {}))
	var familiar: FamiliarData = _roll_familiar(rarity)
	if familiar == null:
		return {"ok": false, "error": "No familiar for rarity"}

	var add_result: Dictionary = GameState.add_familiar(familiar.id)
	GameState.record_recent_pull(familiar.id)
	GameState.record_pack_opened()
	SaveManager.save_game()
	return {
		"ok": true,
		"familiar": familiar,
		"rarity": rarity,
		"add_result": add_result,
	}


func open_free_page() -> Dictionary:
	if GameState.daily_free_page_claimed:
		return {"ok": false, "error": "Already claimed today"}
	if DailyBackend.uses_server_dailies():
		return {"ok": false, "error": "Claim on server first", "needs_server_claim": true}
	if not GameState.claim_daily_free_page():
		return {"ok": false, "error": "Already claimed today"}
	return _roll_free_page_reward()


func roll_claimed_free_page() -> Dictionary:
	if not GameState.daily_free_page_claimed:
		return {"ok": false, "error": "Daily page not claimed"}
	return _roll_free_page_reward()


func _roll_free_page_reward() -> Dictionary:
	var familiar: FamiliarData = _roll_familiar("common")
	if familiar == null:
		return {"ok": false, "error": "Roll failed"}
	var add_result: Dictionary = GameState.add_familiar(familiar.id)
	GameState.record_recent_pull(familiar.id)
	GameState.record_pack_opened()
	SaveManager.save_game()
	return {
		"ok": true,
		"familiar": familiar,
		"rarity": "common",
		"add_result": add_result,
	}


func grant_debug_lumen(amount: int) -> void:
	GameState.grant_lumen(amount)
	SaveManager.save_game()


func _roll_rarity(pack_type: String, odds: Dictionary) -> String:
	if pack_type == "sealed_tome":
		GameState.tome_pity_counter += 1
		var pity: Dictionary = DataLoader.economy_config.get("pity", {})
		if GameState.tome_pity_counter >= int(pity.get("legendary_within", 60)):
			GameState.tome_pity_counter = 0
			return "legendary"
		if GameState.tome_pity_counter % int(pity.get("epic_within", 20)) == 0:
			return "epic"

	var roll := randf() * 100.0
	var cumulative := 0.0
	for rarity in ["legendary", "epic", "rare", "common"]:
		cumulative += float(odds.get(rarity, 0))
		if roll <= cumulative:
			return rarity
	return "common"


func _roll_familiar(rarity: String) -> FamiliarData:
	var pool: Array = DataLoader.get_familiars_by_rarity(rarity)
	if pool.is_empty():
		pool = DataLoader.get_all_familiars()
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()] as FamiliarData

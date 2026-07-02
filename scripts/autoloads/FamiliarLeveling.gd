class_name FamiliarLeveling
extends RefCounted


static func config() -> Dictionary:
	return DataLoader.familiar_levels_config


static func max_level() -> int:
	return int(config().get("max_level", 5))


static func thresholds() -> Array:
	return config().get("dupe_thresholds", [5, 10, 20, 30])


static func total_pages_for_level(level: int) -> int:
	var lvl := clampi(level, 1, max_level())
	var total := 1
	var steps: Array = thresholds()
	for i in range(lvl - 1):
		if i < steps.size():
			total += int(steps[i])
	return total


static func level_from_total_pages(total_pages: int) -> int:
	if total_pages <= 0:
		return 0
	var level := 1
	var cumulative := 1
	for thresh in thresholds():
		if total_pages >= cumulative + int(thresh):
			cumulative += int(thresh)
			level += 1
		else:
			break
	return mini(level, max_level())


static func dupe_threshold_for_level(level: int) -> int:
	if level < 1 or level >= max_level():
		return 0
	var steps: Array = thresholds()
	var idx := level - 1
	if idx < 0 or idx >= steps.size():
		return 0
	return int(steps[idx])


static func progress_to_next_level(total_pages: int, level: int) -> Dictionary:
	if level >= max_level():
		return {"current": 0, "needed": 0, "maxed": true}
	var floor_pages := total_pages_for_level(level)
	var needed := dupe_threshold_for_level(level)
	return {
		"current": maxi(0, total_pages - floor_pages),
		"needed": needed,
		"maxed": false,
	}


static func dust_for_dupe(rarity: String) -> int:
	var table: Dictionary = config().get("dust_per_dupe", {})
	return int(table.get(rarity, table.get("common", 10)))


static func stat_multiplier(level: int) -> float:
	if level <= 1:
		return 1.0
	var bonus: float = float(config().get("stat_bonus_per_level", 0.1))
	return 1.0 + bonus * float(level - 1)


static func apply_level_stats(inst: FamiliarInstance, level: int) -> void:
	var mult := stat_multiplier(level)
	inst.max_hp = maxi(1, int(round(float(inst.max_hp) * mult)))
	inst.current_hp = inst.max_hp
	inst.current_atk = maxi(1, int(round(float(inst.current_atk) * mult)))

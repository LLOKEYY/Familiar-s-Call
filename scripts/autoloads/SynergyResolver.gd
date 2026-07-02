extends Node

const SCHOOLS := ["pyromancy", "nature", "necromancy", "illusion", "military"]
const SCHOOL_SYNERGY_THRESHOLD := 2


func get_active_synergies(squad: Array) -> Dictionary:
	var schools: Dictionary = {}
	for entry in squad:
		if entry == null or not entry is Dictionary:
			continue
		var id: String = entry.get("id", "")
		if id.is_empty():
			continue
		var data: FamiliarData = DataLoader.get_familiar(id)
		if data == null:
			continue
		schools[data.school] = schools.get(data.school, 0) + 1

	var mono: Array = []
	var dual: Array = []
	var mono_cfg: Dictionary = DataLoader.synergy_config.get("mono_school", {})
	var threshold: int = _school_threshold()
	for school in schools:
		var count: int = schools[school]
		var mono_threshold: int = int(mono_cfg.get(school, {}).get("threshold", threshold))
		if mono_cfg.has(school) and count >= mono_threshold:
			mono.append({
				"school": school,
				"name": mono_cfg[school].get("name", school),
				"effect_id": mono_cfg[school].get("effect_id", ""),
			})

	var dual_cfg: Dictionary = DataLoader.synergy_config.get("dual_school", {})
	var dual_threshold: int = int(DataLoader.synergy_config.get("dual_threshold", threshold))
	for key in dual_cfg:
		var parts: PackedStringArray = key.split("+")
		if parts.size() != 2:
			continue
		if schools.get(parts[0], 0) >= dual_threshold and schools.get(parts[1], 0) >= dual_threshold:
			dual.append({
				"key": key,
				"name": str(dual_cfg[key].get("name", key)),
				"effect_id": str(dual_cfg[key].get("effect_id", "")),
			})

	return { "mono": mono, "dual": dual }


func get_dual_keys(squad: Array) -> Array:
	return get_active_synergies(squad).get("dual", [])


func format_synergy_text(synergies: Dictionary) -> String:
	var lines: PackedStringArray = []
	for m in synergies.get("mono", []):
		lines.append("Mono: %s" % m.get("name", ""))
	for d in synergies.get("dual", []):
		lines.append("Combo: %s" % d.get("name", ""))
	if lines.is_empty():
		return "No active synergies"
	return "\n".join(lines)


func get_synergy_display_lines(squad: Array) -> Array:
	var schools: Dictionary = _count_schools(squad)
	var synergies: Dictionary = get_active_synergies(squad)
	var lines: Array = []
	var mono_cfg: Dictionary = DataLoader.synergy_config.get("mono_school", {})
	var dual_cfg: Dictionary = DataLoader.synergy_config.get("dual_school", {})

	for m in synergies.get("mono", []):
		var school: String = str(m.get("school", ""))
		var count: int = int(schools.get(school, 0))
		var effect := _mono_effect_description(str(m.get("effect_id", "")))
		lines.append({
			"text": "%s (%d) — %s" % [_school_display_name(school), count, effect],
			"active": true,
			"color": school_color_for_ui(school),
		})

	for d in synergies.get("dual", []):
		var combo_name: String = str(d.get("name", ""))
		var effect := _dual_effect_description(str(d.get("effect_id", "")))
		lines.append({
			"text": "%s — %s" % [combo_name, effect],
			"active": true,
			"color": BLUE_COLOR,
		})

	if lines.is_empty():
		var hints: Array = []
		for school in SCHOOLS:
			var count: int = int(schools.get(school, 0))
			if count == 0:
				continue
			var mono_threshold: int = int(mono_cfg.get(school, {}).get("threshold", _school_threshold()))
			if count >= mono_threshold:
				continue
			var hint := _dual_hint_for_school(school, schools, dual_cfg)
			if hint.is_empty():
				hint = "need %d more for mono bonus" % (mono_threshold - count)
			hints.append({
				"text": "%s (%d) — %s" % [_school_display_name(school), count, hint],
				"active": false,
				"color": TEXT_DIM_COLOR,
			})
		for hint_line in hints:
			if lines.size() >= 2:
				break
			lines.append(hint_line)

	if lines.is_empty():
		lines.append({
			"text": "No active synergies yet",
			"active": false,
			"color": TEXT_DIM_COLOR,
		})
	return lines


func _count_schools(squad: Array) -> Dictionary:
	var schools: Dictionary = {}
	for entry in squad:
		if entry == null or not entry is Dictionary:
			continue
		var id: String = entry.get("id", "")
		if id.is_empty():
			continue
		var data: FamiliarData = DataLoader.get_familiar(id)
		if data == null:
			continue
		schools[data.school] = schools.get(data.school, 0) + 1
	return schools


func _school_display_name(school: String) -> String:
	match school:
		"necromancy": return "Necromancy"
		"pyromancy": return "Pyromancy"
		"illusion": return "Illusion"
		"military": return "Military"
		"nature": return "Nature"
	return school.capitalize()


func _school_threshold() -> int:
	return SCHOOL_SYNERGY_THRESHOLD


func _dual_hint_for_school(school: String, schools: Dictionary, dual_cfg: Dictionary) -> String:
	var dual_threshold: int = int(DataLoader.synergy_config.get("dual_threshold", _school_threshold()))
	for key in dual_cfg:
		var parts: PackedStringArray = key.split("+")
		if parts.size() != 2:
			continue
		if parts[0] != school and parts[1] != school:
			continue
		var school_a: String = parts[0]
		var school_b: String = parts[1]
		var count_a: int = int(schools.get(school_a, 0))
		var count_b: int = int(schools.get(school_b, 0))
		if count_a >= dual_threshold and count_b >= dual_threshold:
			continue
		var combo_name: String = str(dual_cfg[key].get("name", key))
		var partner: String = school_b if school == school_a else school_a
		var partner_count: int = count_b if school == school_a else count_a
		var self_count: int = count_a if school == school_a else count_b
		if partner_count >= dual_threshold and self_count < dual_threshold:
			return "need %d more for %s" % [dual_threshold - self_count, combo_name]
		if self_count >= 1 and partner_count < dual_threshold:
			return "need %d more %s for %s" % [
				dual_threshold - partner_count,
				_school_display_name(partner),
				combo_name,
			]
	return ""


func _mono_effect_description(effect_id: String) -> String:
	match effect_id:
		"pyro_dmg_10pct": return "attacks deal +10% damage"
		"nature_heal_10pct": return "healing effects +10%"
		"necro_lifesteal_5pct": return "lifesteal +5%"
		"illusion_dodge_5pct": return "dodge chance +5%"
		"military_armor_10pct": return "armor +10%"
	return "mono bonus active"


func _dual_effect_description(effect_id: String) -> String:
	match effect_id:
		"wildfire_shield": return "healing also burns nearby foes"
		"death_magic": return "Pyro attacks bonus vs low-HP foes"
		"phantom_flame": return "burned foes dodge less"
		"scorched_earth": return "Pyro hits front row harder"
		"decay": return "attacks gain lifesteal"
		"feywild": return "healing grants dodge stacks"
		"fortify": return "tanks taunt more effectively"
		"grave_whispers": return "Necro debuffs linger longer"
		"undying_ranks": return "front Necro +50% HP"
		"phantom_drill": return "back Military gain armor"
	return "mixed-house bonus active"


func school_color_for_ui(school: String) -> Color:
	match school:
		"pyromancy": return Color(0.95, 0.55, 0.28)
		"nature": return Color(0.45, 0.85, 0.55)
		"necromancy": return Color(0.65, 0.45, 0.85)
		"illusion": return Color(0.45, 0.65, 0.95)
		"military": return Color(0.7, 0.72, 0.76)
	return Color.WHITE


const TEXT_DIM_COLOR := Color(0.45, 0.46, 0.50)
const BLUE_COLOR := Color(0.28, 0.52, 0.96)

extends Node

const MAX_ROUNDS := 60
var _uid_counter := 0
var _events: Array = []
var _all_units: Array = []
var _team_synergies: Dictionary = {}
var _burn_boost_team: Dictionary = {}
var _ritual_stats: Dictionary = {}
var _current_round: int = 0

const _TAUNT_PASSIVES := [
	"taunt", "taunt_growing_hp", "taunt_stacking_armor", "taunt_frontrow_only",
]
const _DEATH_TRIGGER_PASSIVES := [
	"death_burst_remaining_atk", "death_weaken_atk_10",
]


func simulate_battle(player_squad: Array, enemy_squad: Array) -> Dictionary:
	_uid_counter = 0
	_events = []
	_all_units = []
	_team_synergies = {}
	_burn_boost_team = {}
	_reset_ritual_stats()
	_current_round = 0

	var player_units := _build_team(player_squad, 0)
	var enemy_units := _build_team(enemy_squad, 1)
	_all_units = player_units + enemy_units
	_track_squad_rituals(player_units)

	_team_synergies[0] = SynergyResolver.get_active_synergies(player_squad)
	_team_synergies[1] = SynergyResolver.get_active_synergies(enemy_squad)
	if _team_synergies.get(0, {}).get("dual", []).size() > 0:
		_ritual_stats["had_dual_synergy"] = true
	_apply_team_auras(0, player_units)
	_apply_team_auras(1, enemy_units)

	var initial_hp: Dictionary = {}
	var initial_max_hp: Dictionary = {}
	for u in _all_units:
		initial_hp[u.uid] = u.current_hp
		initial_max_hp[u.uid] = u.max_hp

	for u in _all_units:
		_trigger_on_entry(u)

	for u in _all_units:
		if u.has_passive("heal_lowest_hp_on_start"):
			_heal_lowest_ally(u, 15)
		if u.has_passive("swap_enemy_row_on_start"):
			_swap_random_enemy_row(u)

	var round_num := 1
	var winner := -1
	while round_num <= MAX_ROUNDS:
		if _team_alive_count(0) == 0:
			winner = 1
			break
		if _team_alive_count(1) == 0:
			winner = 0
			break

		_log(round_num, -1, "round_start", -1, 0)
		_current_round = round_num
		_process_round_start(round_num)

		var turn_order := _get_turn_order(round_num)
		for actor in turn_order:
			if actor.is_dead:
				continue
			if actor.skip_next_turn:
				actor.skip_next_turn = false
				_log(round_num, actor.uid, "skip_turn", -1, 0)
				continue
			if actor.blinded and randf() < 0.35:
				_log(round_num, actor.uid, "blinded_skip", -1, 0)
				continue
			_perform_attack(actor, round_num)
			if _team_alive_count(0) == 0 or _team_alive_count(1) == 0:
				break

		for u in _alive_units():
			if not u.is_dead:
				u.rounds_survived += 1
				if u.has_passive("taunt_stacking_armor"):
					u.armor_stacks = mini(3, u.rounds_survived)

		round_num += 1

	if winner == -1:
		winner = 0 if _team_total_hp(0) >= _team_total_hp(1) else 1

	_log(round_num, -1, "battle_end", winner, 0)
	return {
		"winner": winner,
		"events": _events.duplicate(),
		"rounds": round_num,
		"player_units": player_units,
		"enemy_units": enemy_units,
		"initial_hp": initial_hp,
		"initial_max_hp": initial_max_hp,
		"active_duals": {
			0: _team_synergies.get(0, {}).get("dual", []),
			1: _team_synergies.get(1, {}).get("dual", []),
		},
		"ritual_stats": _ritual_stats.duplicate(true),
	}


func _build_team(squad: Array, team: int) -> Array:
	var units: Array = []
	var slot := 0
	for entry in squad:
		if entry == null or not entry is Dictionary:
			continue
		var id: String = entry.get("id", "")
		var data: FamiliarData = DataLoader.get_familiar(id)
		if data == null:
			continue
		var row: String = entry.get("row", "front")
		_uid_counter += 1
		var inst := FamiliarInstance.new(data, team, row, slot, _uid_counter)
		if team == 0:
			var level := GameState.get_familiar_level(id)
			if level > 1:
				FamiliarLeveling.apply_level_stats(inst, level)
		units.append(inst)
		slot += 1
	return units


func _apply_team_auras(team: int, units: Array) -> void:
	var syn: Dictionary = _team_synergies.get(team, {})
	for m in syn.get("mono", []):
		match m.get("effect_id", ""):
			"pyro_dmg_10pct":
				for u in units:
					if u.data.school == "pyromancy":
						u.atk_mult *= 1.1
			"nature_heal_10pct":
				pass
			"necro_lifesteal_5pct":
				pass
			"illusion_dodge_5pct":
				for u in units:
					if u.data.school == "illusion":
						u.dodge_bonus += 0.05
			"military_armor_10pct":
				for u in units:
					if u.data.school == "military":
						u.armor_stacks += 1

	for d in syn.get("dual", []):
		match d.get("effect_id", ""):
			"death_magic":
				pass
			"phantom_flame":
				pass
			"fortify":
				for u in units:
					if u.is_taunting():
						u.armor_stacks += 1
			"undying_ranks":
				for u in units:
					if u.data.school == "necromancy" and u.row == "front":
						u.max_hp = int(u.max_hp * 1.5)
						u.current_hp = u.max_hp
			"phantom_drill":
				for u in units:
					if u.row == "back" and u.data.school == "military":
						u.armor_stacks += 1

	for u in units:
		if u.has_passive("burn_damage_boost_50"):
			_burn_boost_team[team] = true
		if u.has_passive("necro_lifesteal_aura_10"):
			for ally in units:
				if ally.data.school == "necromancy":
					ally.lifesteal_bonus += 0.10
		if u.has_passive("nature_lifesteal_aura_undying"):
			for ally in units:
				if ally.data.school == "nature":
					ally.lifesteal_bonus += 0.10
		if u.has_passive("military_aura_armor_target_reduction"):
			for ally in units:
				if ally.data.school == "military":
					ally.armor_stacks += 1


func _trigger_on_entry(u: FamiliarInstance) -> void:
	if u.has_passive("aoe_backrow_on_entry"):
		var targets := _enemies_in_row(u.team, "back")
		for t in targets:
			_deal_damage(u, t, int(u.effective_atk() * 0.4), false, 1)
	if u.has_passive("accuracy_debuff_on_entry"):
		var enemies := _alive_enemies(u.team)
		if not enemies.is_empty():
			var t: FamiliarInstance = enemies[randi() % enemies.size()]
			var turns := 2
			if _team_has_dual(u.team, "grave_whispers"):
				turns = 3
			t.accuracy_debuff_turns = turns
			_log(0, u.uid, "debuff_accuracy", t.uid, turns)
	if u.has_passive("confuse_skip_turn"):
		var enemies := _alive_enemies(u.team)
		if not enemies.is_empty():
			var t: FamiliarInstance = enemies[randi() % enemies.size()]
			t.skip_next_turn = true
			_log(0, u.uid, "confuse", t.uid, 0)


func _process_round_start(round_num: int) -> void:
	for u in _alive_units():
		if u.burn_turns > 0:
			var burn_dmg := int(u.max_hp * 0.05)
			if _burn_boost_team.get(u.team, false):
				burn_dmg = int(burn_dmg * 1.5)
			var burn_result := _apply_raw_damage(u, burn_dmg, null, true)
			u.burn_turns -= 1
			_log(round_num, u.uid, "burn_tick", u.uid, burn_result.dealt)
			if burn_result.killed:
				_log_death(u, round_num)
			if u.team == 1:
				_ritual_stats["used_burn"] = true
		if u.accuracy_debuff_turns > 0:
			u.accuracy_debuff_turns -= 1

		if u.has_passive("heal_random_odd_rounds") and round_num % 2 == 1:
			_heal_random_ally(u, 10)
		if u.has_passive("heal_frontrow_every_2_rounds") and round_num % 2 == 0:
			for ally in _allies(u.team):
				if ally.row == "front" and not ally.is_dead:
					_heal(ally, 12)
		if u.has_passive("heal_frontrow_5pct_per_round"):
			for ally in _allies(u.team):
				if ally.row == "front" and not ally.is_dead:
					_heal(ally, maxi(1, int(ally.max_hp * 0.05)))


func _get_turn_order(round_num: int) -> Array:
	var units := _alive_units()
	units.sort_custom(func(a: FamiliarInstance, b: FamiliarInstance) -> bool:
		var a_first := a.has_passive("first_strike_fastest_bonus")
		var b_first := b.has_passive("first_strike_fastest_bonus")
		if a_first != b_first:
			return a_first
		return a.effective_speed() > b.effective_speed()
	)
	return units


func _perform_attack(attacker: FamiliarInstance, round_num: int) -> void:
	var attacks := 1
	if attacker.has_passive("double_attack_half_damage"):
		attacks = 2

	for i in attacks:
		var target := _pick_target(attacker)
		if target == null:
			return
		var dmg_mult := 1.0
		if attacker.has_passive("double_attack_half_damage"):
			dmg_mult = 0.5
		if attacker.has_passive("dmg_boost_while_tank_alive_10") and _has_alive_tank(attacker.team):
			dmg_mult *= 1.1
		if attacker.has_passive("execute_below_50") and target.hp_ratio() < 0.5:
			dmg_mult *= 1.25
		if attacker.has_passive("bonus_dmg_vs_taunt_15") and target.is_taunting():
			dmg_mult *= 1.15
		if attacker.has_passive("first_strike_fastest_bonus"):
			var fastest := _fastest_enemy(attacker.team)
			if fastest == target:
				dmg_mult *= 1.2

		var base_dmg := int(attacker.effective_atk() * dmg_mult)
		if attacker.has_passive("execute_missing_hp_10"):
			base_dmg += int((target.max_hp - target.current_hp) * 0.1)

		_deal_damage(attacker, target, base_dmg, true, round_num)

		if attacker.has_passive("guaranteed_burn_first_attack") and not attacker.first_attack_done:
			_apply_burn(target, 2, attacker)
		if attacker.has_passive("burn_on_attack_30") and randf() < 0.3:
			_apply_burn(target, 2, attacker)
		if attacker.has_passive("slow_on_hit_20") and randf() < 0.2:
			target.speed_mod -= 1
		if attacker.has_passive("bounce_attack_50pct"):
			var bounce_targets := _alive_enemies(attacker.team)
			bounce_targets.erase(target)
			if not bounce_targets.is_empty():
				var b: FamiliarInstance = bounce_targets[randi() % bounce_targets.size()]
				_deal_damage(attacker, b, int(base_dmg * 0.5), true, round_num)
		if attacker.has_passive("splash_adjacent_on_attack"):
			for adj in _adjacent_enemies(attacker.team, target):
				_deal_damage(attacker, adj, int(base_dmg * 0.35), false, round_num)
		if attacker.has_passive("repeat_attack_20") and randf() < 0.2 and not target.is_dead:
			_deal_damage(attacker, target, base_dmg, true, round_num)

		attacker.first_attack_done = true


func _pick_target(attacker: FamiliarInstance) -> FamiliarInstance:
	var enemies := _alive_enemies(attacker.team)
	if enemies.is_empty():
		return null

	if not attacker.first_attack_done and attacker.has_passive("target_lowest_hp_first"):
		enemies.sort_custom(func(a, b): return a.current_hp < b.current_hp)
		return enemies[0]

	var front := _enemies_in_row(attacker.team, "front")
	var pool: Array = front if not front.is_empty() else enemies

	var taunts: Array = []
	for e in pool:
		if e.is_taunting():
			taunts.append(e)
	if not taunts.is_empty():
		pool = taunts

	var low_prio: Array = []
	for e in pool:
		if e.data.school == "military" and _team_has_aura(e.team, "military_aura_armor_target_reduction"):
			low_prio.append(e)
	if low_prio.size() < pool.size():
		var normal: Array = []
		for e in pool:
			if e not in low_prio:
				normal.append(e)
		if not normal.is_empty():
			pool = normal

	pool = _filter_valid_targets(pool)
	if pool.is_empty():
		return null
	return pool[randi() % pool.size()]


func _is_valid_target(target: FamiliarInstance) -> bool:
	return target != null and not target.is_dead and target.current_hp > 0


func _filter_valid_targets(pool: Array) -> Array:
	var result: Array = []
	for entry in pool:
		if entry is FamiliarInstance and _is_valid_target(entry):
			result.append(entry)
	return result


func _deal_damage(attacker: FamiliarInstance, target: FamiliarInstance, amount: int, can_dodge: bool, round_num: int) -> void:
	if not _is_valid_target(target):
		return
	if can_dodge and _roll_dodge(target):
		_log(round_num, attacker.uid, "dodge", target.uid, 0)
		return
	if can_dodge and target.accuracy_debuff_turns > 0 and randf() < 0.15:
		_log(round_num, attacker.uid, "miss", target.uid, 0)
		return

	var final := amount
	if attacker.data.school == "pyromancy" and _team_has_dual(attacker.team, "death_magic"):
		if target.hp_ratio() < 0.5:
			final = int(final * 1.2)

	var damage_result := _apply_raw_damage(target, final, attacker, false)
	if damage_result.dealt > 0:
		_log(round_num, attacker.uid, "attack", target.uid, damage_result.dealt)
	if damage_result.killed:
		_log_death(target, round_num)

	_apply_lifesteal(attacker, damage_result.dealt, round_num)
	if attacker.team != target.team and target.burn_turns > 0 and _team_has_dual(attacker.team, "phantom_flame"):
		target.dodge_bonus -= 0.15

	if target.has_passive("reflect_damage_25") and attacker != null and not target.is_dead:
		var reflect := int(damage_result.dealt * 0.25)
		if reflect > 0:
			var reflect_result := _apply_raw_damage(attacker, reflect, target, false)
			if reflect_result.dealt > 0:
				_log(round_num, target.uid, "reflect", attacker.uid, reflect_result.dealt)
			if reflect_result.killed:
				_log_death(attacker, round_num)

	if _team_has_dual(attacker.team, "scorched_earth") and target.row == "front" and attacker != null and not target.is_dead:
		_apply_burn(target, 1, attacker)


func _apply_raw_damage(target: FamiliarInstance, amount: int, source: FamiliarInstance, is_burn: bool) -> Dictionary:
	var empty := {"dealt": 0, "killed": false}
	if target.is_dead:
		return empty
	var dmg := amount

	if is_burn and target.has_passive("execute_missing_hp_10"):
		dmg = int(dmg * 0.8)

	var reduction := 0.0
	if target.armor_stacks > 0:
		reduction += 0.15 * target.armor_stacks
	if target.has_passive("frontrow_damage_reduction_15") and target.row == "front":
		reduction += 0.15
	if target.row == "back":
		for ally in _allies(target.team):
			if ally.has_passive("backrow_damage_reduction_10") and ally.row == "front" and not ally.is_dead:
				reduction += 0.10
				break
	if _team_has_dual(target.team, "feywild") and target.feywild_dodge_stacks > 0:
		reduction += 0.05 * target.feywild_dodge_stacks

	dmg = int(dmg * (1.0 - clampf(reduction, 0.0, 0.75)))

	if target.shield_amount > 0:
		var absorbed := mini(target.shield_amount, dmg)
		target.shield_amount -= absorbed
		dmg -= absorbed

	if dmg <= 0:
		return empty

	var hp_before := target.current_hp
	var would_kill := hp_before - dmg <= 0
	if would_kill and target.has_passive("nature_lifesteal_aura_undying") and not target.undying_used:
		target.current_hp = 1
		target.undying_used = true
		return {"dealt": maxi(0, hp_before - 1), "killed": false}

	target.current_hp -= dmg
	if target.current_hp <= 0:
		_on_death(target, source)
		return {"dealt": dmg, "killed": true}
	return {"dealt": dmg, "killed": false}


func _apply_lifesteal(attacker: FamiliarInstance, damage_dealt: int, round_num: int) -> void:
	if damage_dealt <= 0 or attacker.is_dead:
		return

	var pct := attacker.lifesteal_bonus
	if attacker.has_passive("lifesteal_30"):
		pct = maxf(pct, 0.30)
	elif attacker.has_passive("lifesteal_self_and_adjacent_15"):
		pct = maxf(pct, 0.15)
	if _team_has_mono(attacker.team, "necro_lifesteal_5pct") and attacker.data.school == "necromancy":
		pct += 0.05
	if _team_has_dual(attacker.team, "decay"):
		if pct <= 0.0:
			pct = 0.12
		else:
			pct *= 1.2

	if pct > 0.0:
		_heal(attacker, int(damage_dealt * pct), attacker.uid, "lifesteal")

	if attacker.has_passive("lifesteal_self_and_adjacent_15"):
		for ally in _adjacent_allies(attacker):
			if ally.data.school == "necromancy" and ally != attacker:
				_heal(ally, int(damage_dealt * 0.15), attacker.uid, "heal")


func _scaled_heal_amount(team: int, amount: int) -> int:
	var scaled := amount
	if _team_has_mono(team, "nature_heal_10pct"):
		scaled = int(ceil(float(scaled) * 1.1))
	return maxi(1, scaled)


func _apply_burn(target: FamiliarInstance, turns: int, source: FamiliarInstance = null) -> void:
	target.burn_turns = maxi(target.burn_turns, turns)
	if source != null and source.team == 0:
		_ritual_stats["used_burn"] = true
	if _team_has_dual(target.team, "wildfire"):
		target.shield_amount += 5


func _on_death(unit: FamiliarInstance, killer: FamiliarInstance) -> void:
	unit.is_dead = true
	unit.current_hp = 0

	if unit.team == 0:
		_ritual_stats["player_deaths"] = int(_ritual_stats.get("player_deaths", 0)) + 1
	elif unit.team == 1 and killer != null and killer.team == 0:
		if unit.data.passive_id in _DEATH_TRIGGER_PASSIVES:
			_ritual_stats["enemy_death_trigger_kill"] = true

	if unit.has_passive("death_burst_remaining_atk"):
		var enemies := _alive_enemies(unit.team)
		if not enemies.is_empty():
			var t: FamiliarInstance = enemies[randi() % enemies.size()]
			var burst_result := _apply_raw_damage(t, unit.effective_atk(), unit, false)
			if burst_result.dealt > 0:
				_log(_current_round, unit.uid, "death_burst", t.uid, burst_result.dealt)
			if burst_result.killed:
				_log_death(t, _current_round)
	if unit.has_passive("death_weaken_atk_10"):
		var enemies := _alive_enemies(unit.team)
		if not enemies.is_empty():
			var t: FamiliarInstance = enemies[randi() % enemies.size()]
			t.atk_debuff_mult *= 0.9
			_log(_current_round, unit.uid, "death_weaken", t.uid, 10)

	if _team_has_dual(unit.team, "grave_whispers"):
		var enemies := _alive_enemies(unit.team)
		if not enemies.is_empty():
			enemies[randi() % enemies.size()].blinded = true

	for ally in _allies(unit.team):
		if ally.has_passive("snowball_on_ally_pyro_death") and unit.data.school == "pyromancy":
			ally.atk_mult *= 1.15
		if ally.has_passive("snowball_heal_on_any_ally_death"):
			_heal(ally, int(ally.max_hp * 0.2))
			ally.atk_mult *= 1.05
		if ally.has_passive("taunt_growing_hp"):
			ally.max_hp = int(ally.max_hp * 1.05)
			ally.current_hp = mini(ally.current_hp + int(ally.max_hp * 0.05), ally.max_hp)

	if _team_has_dual(unit.team, "fortify") and unit.is_taunting():
		var allies := _alive_allies(unit.team)
		if not allies.is_empty():
			allies.sort_custom(func(a, b): return a.current_hp < b.current_hp)
			_heal(allies[0], 10, unit.uid, "heal")


func _heal(target: FamiliarInstance, amount: int, source_uid: int = -1, action: String = "heal") -> void:
	if target.is_dead or amount <= 0:
		return
	amount = _scaled_heal_amount(target.team, amount)
	var before := target.current_hp
	target.current_hp = mini(target.max_hp, target.current_hp + amount)
	var healed := target.current_hp - before
	if healed <= 0:
		return
	if target.team == 0:
		_ritual_stats["used_heal_or_lifesteal"] = true
	if _team_has_dual(target.team, "wildfire"):
		target.shield_amount += 5
		var enemies := _alive_enemies(target.team)
		if not enemies.is_empty():
			var burned: FamiliarInstance = enemies[randi() % enemies.size()]
			_apply_burn(burned, 1, null)
			if burned.team == 1:
				_ritual_stats["used_burn"] = true
			_log(_current_round, target.uid, "wildfire_burn", burned.uid, 1)
	if _team_has_dual(target.team, "feywild"):
		target.feywild_dodge_stacks = mini(5, target.feywild_dodge_stacks + 1)
	var actor_uid := source_uid if source_uid >= 0 else target.uid
	_log(_current_round, actor_uid, action, target.uid, healed)


func killer_heals_necro_from_burn(_target: FamiliarInstance, _healed: int) -> bool:
	return false


func _heal_lowest_ally(source: FamiliarInstance, amount: int) -> void:
	var allies := _allies(source.team)
	allies.sort_custom(func(a, b): return a.current_hp < b.current_hp)
	if not allies.is_empty():
		_heal(allies[0], amount)


func _heal_random_ally(source: FamiliarInstance, amount: int) -> void:
	var allies := _alive_allies(source.team)
	if not allies.is_empty():
		_heal(allies[randi() % allies.size()], amount)


func _swap_random_enemy_row(source: FamiliarInstance) -> void:
	var enemies := _alive_enemies(source.team)
	if enemies.is_empty():
		return
	var t: FamiliarInstance = enemies[randi() % enemies.size()]
	t.row = "back" if t.row == "front" else "front"


func _roll_dodge(unit: FamiliarInstance) -> bool:
	var chance := unit.dodge_bonus
	if unit.has_passive("dodge_25"):
		chance += 0.25
	if unit.has_passive("dodge_while_above_half_20") and unit.hp_ratio() > 0.5:
		chance += 0.20
	if unit.burn_turns > 0 and _team_has_dual(unit.team, "phantom_flame"):
		chance -= 0.15
	return randf() < clampf(chance, 0.0, 0.85)


func _team_has_dual(team: int, effect_id: String) -> bool:
	for d in _team_synergies.get(team, {}).get("dual", []):
		if d.get("effect_id", "") == effect_id:
			return true
	return false


func _team_has_mono(team: int, effect_id: String) -> bool:
	for m in _team_synergies.get(team, {}).get("mono", []):
		if m.get("effect_id", "") == effect_id:
			return true
	return false


func _team_has_aura(team: int, passive_id: String) -> bool:
	for u in _all_units:
		if u.team == team and u.has_passive(passive_id) and not u.is_dead:
			return true
	return false


func _alive_units() -> Array:
	var result: Array = []
	for u in _all_units:
		if not u.is_dead:
			result.append(u)
	return result


func _allies(team: int) -> Array:
	var result: Array = []
	for u in _all_units:
		if u.team == team:
			result.append(u)
	return result


func _alive_allies(team: int) -> Array:
	var result: Array = []
	for u in _all_units:
		if u.team == team and not u.is_dead:
			result.append(u)
	return result


func _alive_enemies(team: int) -> Array:
	var result: Array = []
	for u in _all_units:
		if u.team != team and not u.is_dead:
			result.append(u)
	return result


func _enemies_in_row(team: int, row: String) -> Array:
	var result: Array = []
	for u in _all_units:
		if u.team != team and not u.is_dead and u.row == row:
			result.append(u)
	return result


func _adjacent_allies(source: FamiliarInstance) -> Array:
	var same_row := _allies(source.team)
	var result: Array = []
	for ally in same_row:
		if ally != source and not ally.is_dead and absi(ally.slot - source.slot) <= 1:
			result.append(ally)
	return result


func _adjacent_enemies(team: int, target: FamiliarInstance) -> Array:
	var same_row := _enemies_in_row(team, target.row)
	var result: Array = []
	for e in same_row:
		if e != target and absi(e.slot - target.slot) <= 1:
			result.append(e)
	return result


func _fastest_enemy(team: int) -> FamiliarInstance:
	var enemies := _alive_enemies(team)
	if enemies.is_empty():
		return null
	enemies.sort_custom(func(a, b): return a.effective_speed() > b.effective_speed())
	return enemies[0]


func _reset_ritual_stats() -> void:
	_ritual_stats = {
		"player_deaths": 0,
		"had_taunt_familiar": false,
		"schools_fielded": {},
		"had_dual_synergy": false,
		"used_burn": false,
		"used_heal_or_lifesteal": false,
		"enemy_death_trigger_kill": false,
	}


func _track_squad_rituals(player_units: Array) -> void:
	for u in player_units:
		if not u is FamiliarInstance:
			continue
		var school: String = u.data.school
		_ritual_stats["schools_fielded"][school] = true
		if u.data.passive_id in _TAUNT_PASSIVES:
			_ritual_stats["had_taunt_familiar"] = true


func _has_alive_tank(team: int) -> bool:
	for u in _all_units:
		if u.team == team and not u.is_dead and u.data.role == "tank":
			return true
	return false


func _team_alive_count(team: int) -> int:
	var n := 0
	for u in _all_units:
		if u.team == team and not u.is_dead:
			n += 1
	return n


func _team_total_hp(team: int) -> int:
	var total := 0
	for u in _all_units:
		if u.team == team and not u.is_dead:
			total += u.current_hp
	return total


func _log_death(unit: FamiliarInstance, round_num: int) -> void:
	_log(round_num, unit.uid, "death", -1, 0)


func _log(round_num: int, actor_uid: int, action: String, target_uid: int, value: int) -> void:
	_events.append({
		"round": round_num,
		"actor_uid": actor_uid,
		"action": action,
		"target_uid": target_uid,
		"value": value,
	})

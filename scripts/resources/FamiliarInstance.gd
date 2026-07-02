class_name FamiliarInstance
extends RefCounted

var uid: int = 0
var data: FamiliarData
var team: int = 0
var row: String = "front"
var slot: int = 0

var current_hp: int = 0
var max_hp: int = 0
var current_atk: int = 0
var speed_mod: int = 0
var atk_mult: float = 1.0

var burn_turns: int = 0
var armor_stacks: int = 0
var accuracy_debuff_turns: int = 0
var atk_debuff_mult: float = 1.0
var dodge_bonus: float = 0.0
var feywild_dodge_stacks: int = 0

var confused: bool = false
var skip_next_turn: bool = false
var first_attack_done: bool = false
var undying_used: bool = false
var blinded: bool = false
var is_dead: bool = false
var rounds_survived: int = 0

var shield_amount: int = 0
var lifesteal_bonus: float = 0.0


func _init(familiar_data: FamiliarData, p_team: int, p_row: String, p_slot: int, p_uid: int) -> void:
	data = familiar_data
	team = p_team
	row = p_row
	slot = p_slot
	uid = p_uid
	max_hp = data.hp
	current_hp = data.hp
	current_atk = data.atk


func effective_speed() -> int:
	return maxi(1, data.speed + speed_mod)


func effective_atk() -> int:
	return int(current_atk * atk_mult * atk_debuff_mult)


func hp_ratio() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)


func is_taunting() -> bool:
	if is_dead:
		return false
	match data.passive_id:
		"taunt", "taunt_growing_hp", "taunt_stacking_armor":
			return true
		"taunt_frontrow_only":
			return row == "front"
	return false


func has_passive(pid: String) -> bool:
	return data.passive_id == pid

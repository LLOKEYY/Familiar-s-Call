class_name FamiliarData
extends Resource

@export var id: String
@export var display_name: String
@export var school: String
@export var secondary_school: String = ""
@export var rarity: String
@export var role: String
@export var speed: int
@export var hp: int
@export var atk: int
@export var passive_id: String
@export var passive_text: String
@export var art_id: String


static func from_dict(d: Dictionary) -> FamiliarData:
	var f := FamiliarData.new()
	f.id = d.get("id", "")
	f.display_name = d.get("display_name", "")
	f.school = d.get("school", "")
	f.secondary_school = d.get("secondary_school", "")
	f.rarity = d.get("rarity", "common")
	f.role = d.get("role", "damage")
	f.speed = int(d.get("speed", 5))
	f.hp = int(d.get("hp", 50))
	f.atk = int(d.get("atk", 10))
	f.passive_id = d.get("passive_id", "")
	f.passive_text = d.get("passive_text", "")
	f.art_id = d.get("art_id", f.id)
	return f

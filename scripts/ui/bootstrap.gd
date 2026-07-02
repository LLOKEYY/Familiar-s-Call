extends Control

const NAME_PICKER := "res://scenes/name_picker/name_picker.tscn"
const MAIN_MENU := "res://scenes/main_menu/main_menu.tscn"


func _ready() -> void:
	if GameState.needs_profile_setup():
		get_tree().change_scene_to_file(NAME_PICKER)
	else:
		get_tree().change_scene_to_file(MAIN_MENU)

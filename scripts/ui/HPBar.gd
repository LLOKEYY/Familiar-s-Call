class_name HPBar
extends Control

var _bar: ProgressBar
var max_hp: int = 100
var current_hp: int = 100


func _init() -> void:
	custom_minimum_size = Vector2(120, 20)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bar)
	_apply_bar_theme()


func _apply_bar_theme() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.12, 0.10, 0.14)
	bg.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UITheme.HP_FILL
	fill.set_corner_radius_all(3)
	_bar.add_theme_stylebox_override("fill", fill)


func set_values(current: int, maximum: int, animate: bool = false) -> void:
	max_hp = maxi(1, maximum)
	current_hp = clampi(current, 0, max_hp)
	_bar.max_value = max_hp
	var ratio := float(current_hp) / float(max_hp)
	var fill := _bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		fill.bg_color = UITheme.hp_color(ratio)
	if animate and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(_bar, "value", float(current_hp), 0.2).set_ease(Tween.EASE_OUT)
	else:
		_bar.value = float(current_hp)

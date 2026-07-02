class_name FamiliarCard
extends PanelContainer

signal card_pressed(familiar_id: String)
signal card_hovered(familiar_data: FamiliarData, at_position: Vector2)
signal card_unhovered()

var familiar_data: FamiliarData


static func create(data: FamiliarData, compact: bool = false) -> FamiliarCard:
	var card := FamiliarCard.new()
	card.familiar_data = data
	card._build(compact)
	return card


func _build(compact: bool) -> void:
	custom_minimum_size = Vector2(140, 180) if not compact else Vector2(110, 140)
	mouse_filter = Control.MOUSE_FILTER_STOP
	UITheme.apply_panel_style(self)

	var vbox := VBoxContainer.new()
	add_child(vbox)

	var art := ColorRect.new()
	art.custom_minimum_size = Vector2(0, 80 if not compact else 60)
	art.color = UITheme.school_color(familiar_data.school)
	vbox.add_child(art)

	var name_lbl := Label.new()
	name_lbl.text = familiar_data.display_name
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.add_theme_color_override("font_color", UITheme.TEXT)
	vbox.add_child(name_lbl)

	var info := Label.new()
	info.text = "%s | %s" % [familiar_data.school.capitalize(), familiar_data.rarity.capitalize()]
	info.add_theme_font_size_override("font_size", 11)
	info.add_theme_color_override("font_color", UITheme.rarity_color(familiar_data.rarity))
	vbox.add_child(info)

	if not compact:
		var stats := Label.new()
		stats.text = "SPD %d  HP %d  ATK %d" % [familiar_data.speed, familiar_data.hp, familiar_data.atk]
		stats.add_theme_font_size_override("font_size", 11)
		vbox.add_child(stats)

	var sb := get_theme_stylebox("panel")
	if sb:
		var border := sb.duplicate() as StyleBoxFlat
		if border:
			border.border_color = UITheme.rarity_color(familiar_data.rarity)
			add_theme_stylebox_override("panel", border)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		card_pressed.emit(familiar_data.id)


func _on_mouse_entered() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.1)
	card_hovered.emit(familiar_data, global_position)


func _on_mouse_exited() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.1)
	card_unhovered.emit()


static func animate_reveal(card: FamiliarCard) -> void:
	card.scale = Vector2(0.2, 0.2)
	card.modulate.a = 0.0
	card.rotation = -0.08
	var tween := card.create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2(1.08, 1.08), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "modulate:a", 1.0, 0.25)
	tween.tween_property(card, "rotation", 0.0, 0.35)
	tween.chain().tween_property(card, "scale", Vector2.ONE, 0.12)

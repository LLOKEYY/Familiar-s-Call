class_name CurrencyBar
extends HBoxContainer

var dust_label: Label
var lumen_label: Label


func _ready() -> void:
	add_theme_constant_override("separation", 24)
	dust_label = _make_label("Dust: 0")
	lumen_label = _make_label("Lumen: 0")
	add_child(dust_label)
	add_child(lumen_label)
	GameState.currencies_changed.connect(refresh)
	refresh()


func _make_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_color_override("font_color", UITheme.ACCENT)
	return lbl


func refresh() -> void:
	if dust_label == null or lumen_label == null:
		return
	dust_label.text = "Dust: %d" % GameState.dust
	lumen_label.text = "Lumen: %d" % GameState.lumen

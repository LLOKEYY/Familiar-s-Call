class_name CovenFamiliarRow
extends FamiliarPortraitCard

signal familiar_tapped(familiar_id: String)
signal familiar_drag_started(familiar_id: String)
signal press_began
signal press_ended

const HOLD_SEC := 0.38

var drag_enabled: bool = true
var _pointer_down: bool = false
var _hold_timer: float = 0.0
var _drag_started: bool = false


static func create(data: FamiliarData, enable_drag: bool = true) -> CovenFamiliarRow:
	var row := CovenFamiliarRow.new()
	row.familiar_data = data
	row.drag_enabled = enable_drag
	var level := maxi(1, GameState.get_familiar_level(data.id))
	row._build_owned(data.school, level)
	row._wire_gestures()
	return row


func _ready() -> void:
	set_process(false)


func _wire_gestures() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pointer_down = true
			_hold_timer = 0.0
			_drag_started = false
			set_process(true)
			press_began.emit()
		else:
			_finish_pointer()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_pointer_down = true
			_hold_timer = 0.0
			_drag_started = false
			set_process(true)
			press_began.emit()
		else:
			_finish_pointer()


func _process(delta: float) -> void:
	if not drag_enabled or not _pointer_down or _drag_started:
		return
	_hold_timer += delta
	if _hold_timer >= HOLD_SEC:
		_drag_started = true
		set_process(false)
		familiar_drag_started.emit(familiar_data.id)


func _finish_pointer() -> void:
	set_process(false)
	if _pointer_down and not _drag_started:
		familiar_tapped.emit(familiar_data.id)
	_pointer_down = false
	_drag_started = false
	_hold_timer = 0.0
	press_ended.emit()


func cancel_gesture() -> void:
	_pointer_down = false
	_drag_started = false
	_hold_timer = 0.0
	set_process(false)

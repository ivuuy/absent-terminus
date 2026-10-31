extends Node3D
class_name TemporalObject

signal state_changed(object_id: String, state: String, era: int)

@export var object_id := ""
@export var era_states: Array[String] = ["完整", "停电", "腐朽"]
@export var anchorable := true
var anchored_era := -1
var anchored_state := ""
var current_era := 0
var local_state := ""
var _last_state := ""

func configure_era(era: int, override_state: String = "") -> void:
	current_era = clampi(era, 0, era_states.size() - 1)
	local_state = override_state
	_publish()

func bind(era: int, state: String = "") -> void:
	if not anchorable:
		return
	anchored_era = clampi(era, 0, era_states.size() - 1)
	anchored_state = state if not state.is_empty() else era_states[anchored_era]
	_publish()

func release() -> void:
	anchored_era = -1
	anchored_state = ""
	_publish()

func state_for(era: int) -> String:
	if is_bound():
		return anchored_state
	if era == current_era and not local_state.is_empty():
		return local_state
	return era_states[clampi(era, 0, era_states.size() - 1)]

func is_bound() -> bool:
	return anchored_era >= 0

func _publish() -> void:
	var value := state_for(current_era)
	if value != _last_state:
		_last_state = value
		state_changed.emit(object_id, value, current_era)

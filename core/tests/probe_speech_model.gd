extends RefCounted
## A stand-in word and party model for test_speech_seams.gd (not a test file itself). It answers
## every SpeechSim facade call with what it was asked, so a test sees that the facade forwards each
## argument. Like the real models (CONTRACTS.md §9.12), it holds its sim through a WeakRef.

var _sim: WeakRef


func _init(s: SpeechSim) -> void:
	_sim = weakref(s)


## The sim that made this model, or null once it is gone.
func sim() -> SpeechSim:
	return _sim.get_ref() as SpeechSim


func true_wrs_max(ear: String) -> float:
	return 70.0 if ear == "left" else 90.0


func p_wrs_test(_ear: String, level: int) -> float:
	return float(level) / 1000.0


func p_wrs_cross(_ear: String, level: int) -> float:
	return float(level) / 2000.0


func p_wrs(_ear: String, level: int) -> float:
	return float(level) / 100.0


func deal_wrs_list(ear: String, level: int, items: Array, opts: Dictionary = {}) -> Dictionary:
	return {"ear": ear, "level": level, "n": items.size(), "opts": opts}


func respond_wrs(ear: String, level: int, item: Dictionary, outcome: StringName, list_items: Array = [],
		silences: PackedStringArray = PackedStringArray(), style: StringName = &"",
		chatter: PackedStringArray = PackedStringArray()) -> Dictionary:
	return {"ear": ear, "level": level, "id": String(item.get("id", "")), "outcome": outcome,
		"n": list_items.size(), "silences": silences, "style": style, "chatter": chatter}


func true_snr_loss(ear: String = "both") -> float:
	return 9.0 if ear == "both" else 8.0


func effective_snr_loss(ear: String = "both") -> float:
	var s := sim()
	return true_snr_loss(ear) - (4.0 if s != null and s.condition == &"directional" else 0.0)


func p_key_word(snr: float, _ear: String = "both") -> float:
	return snr / 25.0


func respond_sin(snr: int, item: Dictionary, level: int = SpeechRules.SIN_LEVEL_DB,
		ear: String = "both", opts: Dictionary = {}) -> Dictionary:
	return {"snr": snr, "id": String(item.get("id", "")), "level": level, "ear": ear, "opts": opts}

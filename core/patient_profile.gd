class_name PatientProfile
extends Resource
## PatientProfile: one patient's truth and personality (CONTRACTS.md §4.1).
## Owned by core/ (builder A). Loaded with Game.load_patient(id) from res://core/patients/<id>.tres.
## The patient simulator reads ONLY this resource; story reads display_name/complaint/age.

@export var id: String = ""
@export var display_name: String = ""
@export var age: int = 0
@export_multiline var complaint: String = ""

@export_group("True air-conduction thresholds (dB HL)")
## freq (Hz) -> true threshold (dB HL). Must cover every ClinicRules.AC_FREQS entry.
@export var thresholds_right: Dictionary[int, int] = {}
@export var thresholds_left: Dictionary[int, int] = {}

@export_group("Response tendencies")
## Presses per minute of silence with no tone at all (button-mashers are high).
@export_range(0.0, 20.0, 0.1) var false_alarms_per_minute: float = 0.5
## Reaction time range after a heard tone begins (seconds, game time).
@export var reaction_time_min_s: float = 0.6
@export var reaction_time_max_s: float = 1.4
## Psychometric slope (dB): how sharply hearing goes from "never" to "always" around threshold.
@export_range(0.5, 10.0, 0.1) var psychometric_slope_db: float = 2.5
## 0..1, how attentive at the start. Low attention = more misses near threshold.
@export_range(0.0, 1.0, 0.01) var attention: float = 1.0
## Attention lost per presentation (fatigue; a marathon test makes this matter).
@export_range(0.0, 0.05, 0.001) var fatigue_per_tone: float = 0.0
## Tones shorter than this are often missed ("Was that a mosquito?").
@export var min_tone_s: float = 0.5
## 0..1, how quickly the patient "learns your groove" when tones come in a rhythm.
@export_range(0.0, 1.0, 0.01) var rhythm_sensitivity: float = 0.5
## Tinnitus pitch (Hz) or 0 for none. Near this frequency, steady tones are confused.
@export var tinnitus_hz: int = 0

@export_group("Story")
@export var tags: PackedStringArray = []


## True threshold for an ear and frequency. Interpolates on a log-frequency axis if the
## frequency is missing (so any AudiOtron frequency works).
func get_threshold(ear: String, freq: int) -> int:
	var t := get_thresholds(ear)
	if t.has(freq):
		return t[freq]
	if t.is_empty():
		return 0
	var keys: Array = t.keys()
	keys.sort()
	if freq <= int(keys[0]):
		return t[keys[0]]
	if freq >= int(keys[-1]):
		return t[keys[-1]]
	for i in keys.size() - 1:
		var f0: int = keys[i]
		var f1: int = keys[i + 1]
		if freq > f0 and freq < f1:
			var k := log(float(freq) / f0) / log(float(f1) / f0)
			return int(round(lerpf(t[f0], t[f1], k)))
	return 0


func get_thresholds(ear: String) -> Dictionary[int, int]:
	return thresholds_right if ear == "right" else thresholds_left


## Problems with this profile (empty = valid). Used by tests.
func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if id.is_empty():
		out.append("missing id")
	if display_name.is_empty():
		out.append("missing display_name")
	for ear: String in ["right", "left"]:
		var t := get_thresholds(ear)
		for f: int in ClinicRules.AC_FREQS:
			if not t.has(f):
				out.append("%s ear missing %d Hz" % [ear, f])
			elif t[f] < ClinicRules.MIN_DB or t[f] > 120:
				out.append("%s ear %d Hz out of range: %d" % [ear, f, t[f]])
	if reaction_time_min_s > reaction_time_max_s:
		out.append("reaction_time_min_s > reaction_time_max_s")
	return out

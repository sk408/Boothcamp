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

@export_group("True bone-conduction thresholds (dB HL, v3)")
## freq (Hz) -> true bone (cochlear) threshold. Empty = the same as air (no air-bone gap, as in a
## sensorineural loss). When given, must cover every ClinicRules.BC_FREQS entry, and never be
## poorer than air at the same frequency.
@export var bc_right: Dictionary[int, int] = {}
@export var bc_left: Dictionary[int, int] = {}

@export_group("Cross-hearing (v3)")
## This head's REAL interaural attenuation (dB) per transducer: how much a sound loses crossing the
## skull to the other cochlea. Real heads beat the conservative rule values (ClinicRules.IA_RULE_DB:
## phones 40, inserts 55, bone 0), so the rules ask for masking a little more often than needed.
@export var ia_phones_db: int = 60
@export var ia_inserts_db: int = 75
@export var ia_bone_db: int = 0
## Scales ClinicRules.OCCLUSION_DB for this patient (1 = textbook).
@export_range(0.0, 2.0, 0.05) var occlusion_scale: float = 1.0

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
## "he", "she" or "they": fills the {he} {He} {his} {His} {him} tokens in coach and tip texts.
@export_enum("he", "she", "they") var pronoun: String = "he"
## What Hoot and the speech bubbles call the patient ("Gus"). Empty = first word of display_name.
@export var nickname: String = ""


const _PRONOUNS := {
	"he": {"he": "he", "He": "He", "his": "his", "His": "His", "him": "him"},
	"she": {"he": "she", "He": "She", "his": "her", "His": "Her", "him": "her"},
	"they": {"he": "they", "He": "They", "his": "their", "His": "Their", "him": "them"},
}


## The short name the game calls this patient ("Gus", "Bonnie").
func short_name() -> String:
	if nickname != "":
		return nickname
	var parts := display_name.split(" ", false)
	return parts[0] if not parts.is_empty() else id.capitalize()


## Replaces the pronoun tokens ({he} {He} {his} {His} {him}) and {name} in a text.
func say(text: String) -> String:
	return PatientProfile.pronouns(text, pronoun).replace("{name}", short_name())


## Pronoun tokens for any pronoun ("he" when unknown). Static so texts without a patient work too.
static func pronouns(text: String, which: String) -> String:
	if text.find("{") < 0:
		return text
	var map: Dictionary = _PRONOUNS.get(which, _PRONOUNS["he"])
	for k: String in ["He", "His", "he", "his", "him"]:
		text = text.replace("{%s}" % k, String(map[k]))
	return text


## True threshold for an ear and frequency. Interpolates on a log-frequency axis if the
## frequency is missing (so any AudiOtron frequency works).
func get_threshold(ear: String, freq: int) -> int:
	return _interp(get_thresholds(ear), freq)


static func _interp(t: Dictionary[int, int], freq: int) -> int:
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


## (v3) True bone (cochlear) threshold. Without bone data it equals air (no gap). Never poorer
## than air (log-frequency interpolation like get_threshold()).
func get_bc_threshold(ear: String, freq: int) -> int:
	var t := get_bc_thresholds(ear)
	var ac := get_threshold(ear, freq)
	if t.is_empty():
		return ac
	return mini(_interp(t, freq), ac)


func get_bc_thresholds(ear: String) -> Dictionary[int, int]:
	return bc_right if ear == "right" else bc_left


func has_bone_data() -> bool:
	return not bc_right.is_empty() or not bc_left.is_empty()


## (v3) Real IA for a transducer (&"phones", &"inserts", &"bone").
func get_ia(transducer: StringName) -> int:
	match transducer:
		&"bone":
			return ia_bone_db
		&"inserts":
			return ia_inserts_db
	return ia_phones_db


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
	for ear: String in ["right", "left"]:
		var b := get_bc_thresholds(ear)
		if b.is_empty():
			continue
		for f: int in ClinicRules.BC_FREQS:
			if not b.has(f):
				out.append("%s bone missing %d Hz" % [ear, f])
			elif b[f] < ClinicRules.MIN_DB or b[f] > ClinicRules.max_db_for(f, &"bone") + 30:
				out.append("%s bone %d Hz out of range: %d" % [ear, f, b[f]])
			elif b[f] > get_threshold(ear, f):
				out.append("%s bone %d Hz poorer than air" % [ear, f])
	if reaction_time_min_s > reaction_time_max_s:
		out.append("reaction_time_min_s > reaction_time_max_s")
	return out

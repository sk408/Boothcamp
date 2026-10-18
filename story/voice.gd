extends Node
## Voice: quiet gibberish "syllable" voices for the dialogue (no recorded speech, no words).
## Each speaker gets a small bank of synthesized syllables (a glottal buzz shaped by two
## vowel formants, with a soft consonant tick), generated once and cached.
## Peaks sit at VOICE_PEAK_DBFS and pass AudioSafety.clamp_sample. Plays on the "Voice" bus,
## whose volume follows the "sfx_volume" setting.
## Usage (story-internal): const Voice := preload("res://story/voice.gd"); var v := Voice.new()
##   add_child(v); v.syllable("Gus", 3)

const MIX_RATE := 22050
const VOICE_PEAK_DBFS := -24.0
const PLAYERS := 4
const SYLLABLE_S := 0.085
## Muffled bank (Gus before his hearing aids): a sloping high-shelf cut like his audiogram,
## the vowels stay (loud enough), the high harmonics and consonant ticks fade (not clear).
const MUFFLE_SHELF_LO_HZ := 1000.0
const MUFFLE_SHELF_HI_HZ := 2500.0
const MUFFLE_CUT_DB := 25.0

## f0 (Hz), pitch wobble, brightness (harmonic roll-off), vowel set.
const SPEAKERS: Dictionary = {
	"Gus": {"f0": 128.0, "wobble": 0.06, "roll": 0.72, "vowels": ["a", "o", "u", "e", "a", "o"]},
	"Hoot": {"f0": 410.0, "wobble": 0.10, "roll": 0.55, "vowels": ["u", "o", "u", "o", "i", "u"]},
	"Doris": {"f0": 235.0, "wobble": 0.08, "roll": 0.68, "vowels": ["e", "i", "a", "e", "o", "i"]},
}
## Rough vowel formants (F1, F2) in Hz.
const FORMANTS: Dictionary = {
	"a": [750.0, 1250.0], "e": [500.0, 1800.0], "i": [320.0, 2300.0], "o": [480.0, 900.0], "u": [340.0, 780.0],
}

static var _banks: Dictionary = {}
## (cases) Extra speakers a level registers at run time (the case files' "voice"), same keys as SPEAKERS.
static var _extra: Dictionary = {}

var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	var bus: StringName = AudioSafety.VOICE_BUS if AudioServer.get_bus_index(AudioSafety.VOICE_BUS) >= 0 else &"Master"
	for i in PLAYERS:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		add_child(p)
		_players.append(p)
	_apply_volume()
	Events.settings_changed.connect(func(key: String, _v: Variant) -> void:
		if key == "sfx_volume":
			_apply_volume())


static func has_voice(speaker: String) -> bool:
	return SPEAKERS.has(speaker) or _extra.has(speaker)


## (cases) Give a speaker a voice: {"f0", "wobble", "roll", "vowels"} (missing keys use Gus's).
## The built-in speakers keep theirs.
static func register(speaker: String, spec: Dictionary) -> void:
	if speaker == "" or SPEAKERS.has(speaker):
		return
	var full: Dictionary = (SPEAKERS["Gus"] as Dictionary).duplicate(true)
	for k: String in ["f0", "wobble", "roll"]:
		if spec.has(k):
			full[k] = float(spec[k])
	if spec.get("vowels", []) is Array and not (spec.get("vowels", []) as Array).is_empty():
		full["vowels"] = (spec["vowels"] as Array).duplicate()
	_extra[speaker] = full
	_banks.erase(speaker)
	_banks.erase(speaker + "|muffled")


## Play syllable number i (any int) for the speaker. Quiet, short, safe to call every few letters.
func syllable(speaker: String, i: int, volume_db: float = 0.0) -> void:
	if not has_voice(speaker):
		return
	var m := world_muffle()
	var bank := bank_for(speaker, m > 0.4)
	if bank.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = bank[absi(i) % bank.size()]
	p.pitch_scale = Game.rng.randf_range(0.94, 1.07)
	p.volume_db = minf(volume_db - 3.0 * m, 0.0)
	p.play()


## How muffled the clinic sounds right now (the grey fitting world), 0 when there is no clinic.
static func world_muffle() -> float:
	var c: Node = Stage.clinic
	if c == null or not is_instance_valid(c) or not c.has_method("get_muffle"):
		return 0.0
	return clampf(float(c.call("get_muffle")), 0.0, 1.0)


## The syllable bank for a speaker. muffled = the high harmonics and consonant ticks rolled off
## (how the world sounds to Gus before his hearing aids go on).
static func bank_for(speaker: String, muffled: bool = false) -> Array:
	var key := speaker + ("|muffled" if muffled else "")
	if _banks.has(key):
		return _banks[key]
	var spec: Dictionary = SPEAKERS[speaker] if SPEAKERS.has(speaker) else _extra[speaker]
	var bank: Array = []
	var vowels: Array = spec["vowels"]
	for i in vowels.size():
		var rise := 1.0 + (0.08 if i % 2 == 0 else -0.05)
		bank.append(_to_wav(_make_syllable(spec, String(vowels[i]), rise, i, muffled)))
	_banks[key] = bank
	return bank


static func _make_syllable(spec: Dictionary, vowel: String, rise: float, idx: int, muffled: bool = false) -> PackedFloat32Array:
	var n := int(SYLLABLE_S * MIX_RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var f0: float = spec["f0"]
	var roll: float = spec["roll"]
	var wob: float = spec["wobble"]
	var fm: Array = FORMANTS.get(vowel, FORMANTS["a"])
	var f1: float = fm[0]
	var f2: float = fm[1]
	# harmonic weights from the two formant peaks (computed once per syllable)
	var count := mini(14, int(3200.0 / f0))
	var weights := PackedFloat32Array()
	weights.resize(count)
	for h in count:
		var hf := f0 * float(h + 1)
		var w1 := 1.0 / (1.0 + pow((hf - f1) / 160.0, 2.0))
		var w2 := 0.6 / (1.0 + pow((hf - f2) / 260.0, 2.0))
		weights[h] = (w1 + w2 + 0.05) * pow(roll, float(h))
		if muffled:
			var k_shelf := smoothstep(MUFFLE_SHELF_LO_HZ, MUFFLE_SHELF_HI_HZ, hf)
			weights[h] *= db_to_linear(-MUFFLE_CUT_DB * k_shelf)
	var phase := 0.0
	var seed_v := 1013 + idx * 7919
	for i in n:
		var t := float(i) / MIX_RATE
		var k := float(i) / float(n)
		var f := f0 * lerpf(1.0, rise, k) * (1.0 + wob * sin(TAU * 7.0 * t))
		phase += TAU * f / MIX_RATE
		var v := 0.0
		for h in count:
			v += weights[h] * sin(phase * float(h + 1))
		var env := minf(1.0, t / 0.012) * pow(1.0 - k, 1.6)
		# consonant tick: a few ms of soft noise at the start
		seed_v = (seed_v * 1103515245 + 12345) & 0x7fffffff
		var noise := (float(seed_v) / float(0x7fffffff)) * 2.0 - 1.0
		var tick := 0.0 if muffled else noise * 0.25 * exp(-t * 400.0)
		out[i] = v * env + tick
	return out


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := pow(10.0, VOICE_PEAK_DBFS / 20.0) / peak
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		var v := AudioSafety.clamp_sample(samples[i] * gain)
		data.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w


func _apply_volume() -> void:
	var idx := AudioServer.get_bus_index(AudioSafety.VOICE_BUS)
	if idx < 0:
		return
	var lin := clampf(float(Game.settings.get("sfx_volume", 0.8)), 0.0, 1.0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(lin) if lin > 0.001 else -80.0)

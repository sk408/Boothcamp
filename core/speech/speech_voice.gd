class_name SpeechVoice
extends Node
## SpeechVoice: the quiet "voice" of the speech tests (CONTRACTS.md §9.6, docs/SPEECH.md §7).
##  - Every word plays as a short synthesized murmur (voiced syllables on formant-shaped harmonics),
##    one syllable per part of the word, in the test ear's channel only.
##  - A recording dropped at res://assets/speech/<list_id>/<item_id>.wav replaces the murmur
##    (8- or 16-bit PCM, mono or stereo, any rate; project.godot imports WAVs uncompressed), in
##    the test ear only, scaled to the same safe level over its speech (not its silence or room
##    noise) and clamped sample by sample. A file the voice can't decode plays the murmur.
##  - Speech noise for masking: speech-shaped noise in the OTHER ear, masker mapping and clamp.
##  - Level ALWAYS goes through AudioSafety.speech_to_rms() (words) and masker_to_rms() (noise), and
##    every sample through AudioSafety.clamp_sample() / clamp_masker_sample(). Nothing is ever loud.
## render(frames) is pure DSP (no audio server), so tests can measure exactly what would play.
## Every word also lights the screen's TALK lamp: nothing depends on hearing it.
## (Day 5) The party of the Party Noise Test (CONTRACTS.md §9.16): SpeechBabble's loop of four
## murmuring talkers in the test ear(s), on the masker's safety path (babble_rms(): masker_to_rms(),
## then clamp_masker_sample() on every babble sample and clamp_sample() on the mix). play_item("both")
## writes both channels (the same mix in both ears, or the speakers); "right" and "left" are as
## before, and Day 3 never passes "both". The PARTY mode times it (the party first, then the talker);
## the babble stops on stop_babble(), when the voice leaves the tree, and when the game pauses.

const MIX_RATE := 22050.0
const SYLLABLE_S := 0.30
const SYLLABLE_GAP_S := 0.06
const ATTACK_S := 0.03
const RELEASE_S := 0.09
const F0_HZ := 128.0
const HARMONICS := 12
## Vowel formants [F1, F2] (Hz) the murmur cycles through.
const VOWELS: Array = [[730, 1090], [530, 1840], [300, 2300], [570, 840], [440, 1020], [660, 1720]]
const NOISE_RAMP_S := 0.05
## Speech noise: white noise through two one-pole low-passes at about this corner (speech-shaped).
const NOISE_CORNER_HZ := 900.0

var ear: String = "right"
var level_hl: float = 0.0
var noise_on: bool = false
var noise_ear: String = "left"
var noise_db: float = 0.0

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _buf := PackedFloat32Array()   ## the current word, unit RMS over its voiced part
var _pos := 0
var _n_ramp := 0.0
var _n_gain := 0.0
var _lp1 := 0.0
var _lp2 := 0.0
var _n_rng := RandomNumberGenerator.new()
static var _murmur_cache: Dictionary = {}
static var _warned: Dictionary = {}
static var _noise_norm := 0.0
## Generators of freed voices, kept a while longer. The engine's generator playback points at its
## stream without holding it, and a player freed while playing is mixed once more (its fade-out)
## after the stream is gone: that read of freed memory once spun the audio thread forever.
const RETIRED_KEEP := 16
static var _retired: Array[AudioStream] = []

# ---------------------------------------------------------------- (Day 5) the party babble
## Dial dB added before the masker mapping, so a 0 dB SNR plays the party at the words' RMS
## (masker_to_rms(x) equals speech_to_rms(hl) at x = hl - 5).
const BABBLE_TRIM_DB := -5.0
## The party starts this long before the talker, and stops this long after the sentence.
const BABBLE_LEAD_S := 0.6
const BABBLE_TAIL_S := 0.3
var babble_on: bool = false
## "right", "left" or "both" (the same party in both ears, or the speakers).
var babble_ear: String = "both"
var babble_db: int = 0
var _b_pos := 0
var _b_ramp := 0.0
var _b_gain := 0.0


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.1
	_player.stream = gen
	_player.bus = _bus()
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _notification(what: int) -> void:
	# (Day 5) the party never plays on under the pause menu, or after the voice has gone
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_EXIT_TREE:
		_cut_babble()
	if what == NOTIFICATION_PREDELETE and _player != null and _player.stream != null:
		_retired.append(_player.stream)
		while _retired.size() > RETIRED_KEEP:
			_retired.pop_front()


static func _bus() -> StringName:
	return AudioSafety.TONES_BUS if AudioServer.get_bus_index(AudioSafety.TONES_BUS) >= 0 else &"Master"


## Play one item in an ear at a level. Returns how long it plays (seconds, real time of the audio;
## the screen uses its own game-time timer for the TALK lamp).
func play_item(p_ear: String, list_id: String, it: Dictionary, hl: float) -> float:
	stop()
	ear = p_ear
	level_hl = hl
	var path := SpeechMaterial.recording_path(list_id, String(it.get("id", "")))
	if path != "":
		var stream: Variant = load(path)
		var pcm := wav_to_mono(stream as AudioStreamWAV) if stream is AudioStreamWAV else PackedFloat32Array()
		if not pcm.is_empty():
			_buf = normalised_speech(pcm)
			_pos = 0
			return _buf.size() / MIX_RATE
		if not _warned.has(path):
			_warned[path] = true
			push_warning("SpeechVoice: can't decode %s (needs an uncompressed 8- or 16-bit WAV); the murmur plays" % path)
	_buf = murmur(syllables_for(it), String(it.get("id", "")).hash())
	_pos = 0
	return _buf.size() / MIX_RATE


func stop() -> void:
	_buf = PackedFloat32Array()
	_pos = 0


func is_playing() -> bool:
	return _pos < _buf.size()


func set_level(hl: float) -> void:
	level_hl = hl


## Speech noise on in one ear (the non-test ear) at a masker level (dB EM).
func start_noise(p_ear: String, db_em: float) -> void:
	if not noise_on and _n_ramp <= 0.0:
		_n_gain = AudioSafety.masker_to_rms(db_em) * _noise_gain_norm()
	noise_ear = p_ear
	noise_db = db_em
	noise_on = true


func set_noise(db_em: float) -> void:
	noise_db = db_em


func stop_noise() -> void:
	noise_on = false


## (Day 5) The party starts in `p_ear` ("right", "left" or "both") at a party level (dial dB): it
## fades in over NOISE_RAMP_S and loops until stop_babble(). The loop is built on first use.
func start_babble(p_ear: String, p_babble_db: int) -> void:
	SpeechBabble.loop()
	if not babble_on and _b_ramp <= 0.0:
		_b_gain = babble_rms(p_babble_db)
	babble_ear = p_ear
	babble_db = p_babble_db
	babble_on = true


## (Day 5) The party steps up (or down) to a new level; the change glides over a few ms.
func set_babble(p_babble_db: int) -> void:
	babble_db = p_babble_db


## (Day 5) The party fades out (NOISE_RAMP_S).
func stop_babble() -> void:
	babble_on = false


## (Day 5) The party is playing, or still fading out.
func is_babbling() -> bool:
	return babble_on or _b_ramp > 0.0


## (Day 5) The babble loop is built, so the first party sentence needs no wait.
func babble_ready() -> bool:
	return SpeechBabble.is_built()


## (Day 5) The babble's RMS (0..1) at a party level: the masker mapping, BABBLE_TRIM_DB down.
static func babble_rms(p_babble_db: int) -> float:
	return AudioSafety.masker_to_rms(float(p_babble_db) + BABBLE_TRIM_DB)


## The party stops at once, with no fade (pause, leaving the tree).
func _cut_babble() -> void:
	babble_on = false
	_b_ramp = 0.0


## Syllables of an item: the parts of a spondee, one for a single word, about 1.4 per word of a sentence.
static func syllables_for(it: Dictionary) -> int:
	var parts: Array = it.get("parts", [])
	if parts.size() > 0:
		return parts.size()
	var words := String(it.get("text", "")).split(" ", false).size()
	return 1 if words <= 1 else int(ceil(words * 1.4))


## A murmur of n voiced syllables, unit RMS (cached by syllable count and seed).
static func murmur(n: int, seed_value: int) -> PackedFloat32Array:
	var key := "%d:%d" % [n, seed_value]
	if _murmur_cache.has(key):
		return _murmur_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedFloat32Array()
	var syl := int(SYLLABLE_S * MIX_RATE)
	var gap := int(SYLLABLE_GAP_S * MIX_RATE)
	var phase := 0.0
	for s in n:
		var v: Array = VOWELS[rng.randi_range(0, VOWELS.size() - 1)]
		var f1 := float(v[0])
		var f2 := float(v[1])
		var f0 := F0_HZ * rng.randf_range(0.95, 1.08)
		var weights := PackedFloat32Array()
		for h in HARMONICS:
			var fh := f0 * (h + 1)
			# two Lorentzian formant peaks over a gentle tilt
			var w := 1.0 / (1.0 + pow((fh - f1) / 90.0, 2.0)) + 0.6 / (1.0 + pow((fh - f2) / 120.0, 2.0)) + 0.05 / (h + 1)
			weights.append(w)
		for i in syl:
			var t := float(i) / MIX_RATE
			var env := minf(1.0, t / ATTACK_S) * minf(1.0, (SYLLABLE_S - t) / RELEASE_S)
			var f := f0 * (1.0 - 0.12 * t / SYLLABLE_S)   # falling pitch, like a spoken word
			phase = fmod(phase + f / MIX_RATE, 1.0)
			var x := 0.0
			for h in HARMONICS:
				x += weights[h] * sin(TAU * phase * (h + 1))
			# a breath of noise at the onset (the consonant)
			if t < 0.03:
				x += rng.randf_range(-0.6, 0.6) * (1.0 - t / 0.03)
			out.append(x * maxf(env, 0.0))
		if s < n - 1:
			for i in gap:
				out.append(0.0)
	out = normalised(out)
	_murmur_cache[key] = out
	return out


## Scale to unit RMS over the non-silent samples.
static func normalised(pcm: PackedFloat32Array) -> PackedFloat32Array:
	var sum := 0.0
	var n := 0
	for x: float in pcm:
		if absf(x) > 1e-5:
			sum += x * x
			n += 1
	if n == 0:
		return pcm
	var k := 1.0 / sqrt(sum / n)
	var out := PackedFloat32Array()
	out.resize(pcm.size())
	for i in pcm.size():
		out[i] = pcm[i] * k
	return out


## Window length and gate for normalised_speech(): 20 ms windows; a window counts as speech when it
## is within SPEECH_GATE_DB of the loudest one.
const SPEECH_WINDOW_S := 0.02
const SPEECH_GATE_DB := 35.0


## A recording scaled to unit RMS over its speech: the 20 ms windows within SPEECH_GATE_DB of the
## loudest window. Leading silence, pauses and room noise don't pull the level up.
static func normalised_speech(pcm: PackedFloat32Array) -> PackedFloat32Array:
	var win := maxi(1, int(SPEECH_WINDOW_S * MIX_RATE))
	var energies := PackedFloat32Array()
	var loudest := 0.0
	for start in range(0, pcm.size(), win):
		var e := 0.0
		var n := mini(win, pcm.size() - start)
		for i in n:
			e += pcm[start + i] * pcm[start + i]
		e /= float(n)
		energies.append(e)
		loudest = maxf(loudest, e)
	if loudest <= 0.0:
		return pcm
	var gate := loudest * pow(10.0, -SPEECH_GATE_DB / 10.0)
	var sum := 0.0
	var count := 0
	for e: float in energies:
		if e >= gate:
			sum += e
			count += 1
	var k := 1.0 / sqrt(sum / count)
	var out := PackedFloat32Array()
	out.resize(pcm.size())
	for i in pcm.size():
		out[i] = pcm[i] * k
	return out


## An uncompressed 8- or 16-bit WAV as mono floats at MIX_RATE (nearest-sample resampling).
## Empty if unsupported (compressed imports: IMA ADPCM, QOA).
static func wav_to_mono(w: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if w == null or (w.format != AudioStreamWAV.FORMAT_16_BITS and w.format != AudioStreamWAV.FORMAT_8_BITS):
		return out
	var bytes := 2 if w.format == AudioStreamWAV.FORMAT_16_BITS else 1
	var data := w.data
	var ch := 2 if w.stereo else 1
	var frames := data.size() / (bytes * ch)
	if frames <= 0:
		return out
	var ratio := float(w.mix_rate) / MIX_RATE
	var n := int(frames / ratio)
	out.resize(n)
	for i in n:
		var fi := mini(int(i * ratio), frames - 1)
		var acc := 0.0
		for c in ch:
			if bytes == 2:
				acc += float(data.decode_s16((fi * ch + c) * 2)) / 32768.0
			else:
				acc += float(data.decode_s8(fi * ch + c)) / 128.0
		out[i] = acc / ch
	return out


func _noise_gain_norm() -> float:
	# RMS of the two-pole low-passed uniform noise, measured once
	if _noise_norm <= 0.0:
		var r := RandomNumberGenerator.new()
		r.seed = 7
		var a := _lp_coeff()
		var y1 := 0.0
		var y2 := 0.0
		var sum := 0.0
		var n := 22050
		for i in n:
			y1 += a * (r.randf_range(-1.0, 1.0) - y1)
			y2 += a * (y1 - y2)
			sum += y2 * y2
		_noise_norm = 1.0 / maxf(sqrt(sum / n), 1e-4)
	return _noise_norm


static func _lp_coeff() -> float:
	return 1.0 - exp(-TAU * NOISE_CORNER_HZ / MIX_RATE)


## Synthesize the next `frames` stereo frames (x = left, y = right). Advances the word and the noise.
func render(frames: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames)
	if noise_on or _n_ramp > 0.0:
		var target := AudioSafety.masker_to_rms(noise_db) * _noise_gain_norm() if noise_on else _n_gain
		var ramp_step := 1.0 / (NOISE_RAMP_S * MIX_RATE)
		var goal := 1.0 if noise_on else 0.0
		var a := _lp_coeff()
		var right := noise_ear == "right"
		for i in frames:
			_n_ramp = move_toward(_n_ramp, goal, ramp_step)
			_n_gain += (target - _n_gain) * 0.01
			_lp1 += a * (_n_rng.randf_range(-1.0, 1.0) - _lp1)
			_lp2 += a * (_lp1 - _lp2)
			var env := 0.5 - 0.5 * cos(PI * _n_ramp)
			var v := AudioSafety.clamp_masker_sample(_lp2 * _n_gain * env)
			out[i] = Vector2(out[i].x, v) if right else Vector2(v, out[i].y)
	if babble_on or _b_ramp > 0.0:
		_render_babble(out)
	if _pos < _buf.size():
		var g := AudioSafety.speech_to_rms(level_hl)
		var right_w := ear == "right"
		var both_w := ear == "both"   # (Day 5) the party test: the talker in both ears (or the speakers)
		for i in frames:
			if _pos >= _buf.size():
				break
			var v := _buf[_pos] * g
			_pos += 1
			if both_w:
				out[i] = Vector2(AudioSafety.clamp_sample(out[i].x + v), AudioSafety.clamp_sample(out[i].y + v))
			elif right_w:
				out[i] = Vector2(out[i].x, AudioSafety.clamp_sample(out[i].y + v))
			else:
				out[i] = Vector2(AudioSafety.clamp_sample(out[i].x + v), out[i].y)
	return out


## (Day 5) The party into `out`, in babble_ear's channel(s): each babble sample through
## clamp_masker_sample(), the channel through clamp_sample(). Advances the loop and the fade.
func _render_babble(out: PackedVector2Array) -> void:
	var loop := SpeechBabble.loop()
	if loop.is_empty():
		_b_ramp = 0.0
		return
	var target := babble_rms(babble_db) if babble_on else _b_gain
	var ramp_step := 1.0 / (NOISE_RAMP_S * MIX_RATE)
	var goal := 1.0 if babble_on else 0.0
	var to_right := babble_ear != "left"
	var to_left := babble_ear != "right"
	var n := loop.size()
	for i in out.size():
		_b_ramp = move_toward(_b_ramp, goal, ramp_step)
		_b_gain += (target - _b_gain) * 0.01
		var env := 0.5 - 0.5 * cos(PI * _b_ramp)
		var b := AudioSafety.clamp_masker_sample(loop[_b_pos] * _b_gain * env)
		_b_pos = (_b_pos + 1) % n
		var o := out[i]
		out[i] = Vector2(AudioSafety.clamp_sample(o.x + b) if to_left else o.x, AudioSafety.clamp_sample(o.y + b) if to_right else o.y)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	_playback.push_buffer(render(frames))

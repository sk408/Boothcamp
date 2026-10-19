extends Node
## Sfx: quiet, synthesized UI and gag sounds (autoload "Sfx"). No sound files.
##
## Sfx.play(&"stamp")                 # one-shot
## Sfx.play(&"blip", 1.3)             # pitch-scaled (dialogue blips, combo steps)
## Sfx.play_note(523.25)              # bell note at any frequency (audiogram melody)
## Every sound is normalised to AudioSafety.SFX_PEAK_DBFS and plays on the "Sfx" bus.
## The "boing" gag sound is normal loudness: comedy is visual, never loud.
## Add new sounds by adding a _gen_<name>() function and the name to SOUNDS.
## Music: Sfx.music_start() / music_stop() / music_duck(on, owner). One gentle ~8.6 s marimba loop,
## synthesized on a worker thread at boot, on the "Music" bus, well below the effects. The
## AudiOtron and Hoot's movies duck it to silence (reference-counted owners) so the test
## beeps are always alone.

const MIX_RATE := 22050
const VOICES := 10
const SOUNDS: Array[StringName] = [
	&"click", &"blip", &"thunk", &"stamp", &"ding", &"boing", &"pop", &"whoosh", &"kaching",
	&"sad_trombone", &"squeak", &"fanfare", &"chirp", &"pen", &"door", &"note", &"sparkle", &"error",
]
const NOTE_BASE_HZ := 523.25  ## the "note" sample is a C5 bell

const MUSIC_BPM := 112.0
const MUSIC_DB := -15.0
## C, A minor, F, G: [bass root Hz, arpeggio notes Hz]
const MUSIC_CHORDS: Array = [
	[130.81, [523.25, 659.25, 783.99, 1046.5]],
	[110.0, [440.0, 523.25, 659.25, 880.0]],
	[87.31, [349.23, 440.0, 523.25, 698.46]],
	[98.0, [392.0, 493.88, 587.33, 783.99]],
]
const ARP: Array[int] = [0, 1, 2, 3, 2, 1, 2, 1]

var _cache: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music: AudioStreamPlayer
var _music_stream: AudioStreamWAV
var _music_samples := PackedFloat32Array()
var _music_task := -1
var _music_want := false
var _music_ducked := false
var _duck_owners: Dictionary = {}  ## owner key -> true
var _music_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = AudioSafety.SFX_BUS if AudioServer.get_bus_index(AudioSafety.SFX_BUS) >= 0 else &"Master"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.name = "Music"
	_music.bus = AudioSafety.MUSIC_BUS if AudioServer.get_bus_index(AudioSafety.MUSIC_BUS) >= 0 else &"Master"
	_music.volume_db = MUSIC_DB
	add_child(_music)
	_music_task = WorkerThreadPool.add_task(_build_music, false, "music loop")
	warm_up.call_deferred()


## Synthesize every effect ahead of time, one per frame, so the first stamp never hitches.
func warm_up() -> void:
	for sname: StringName in SOUNDS:
		if not is_inside_tree():
			return
		get_stream(sname)
		await get_tree().process_frame


func _process(_delta: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		_music_stream = _to_wav(_music_samples)
		_music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_music_stream.loop_begin = 0
		_music_stream.loop_end = _music_samples.size()
		_music_samples = PackedFloat32Array()
		if _music_want:
			_music_play()


## Start the background loop (idempotent; starts as soon as it is synthesized).
func music_start() -> void:
	_music_want = true
	if _music_stream != null:
		_music_play()


func music_stop() -> void:
	_music_want = false
	if _music != null:
		_music.stop()


## Duck the music to silence or bring it back. Reference-counted by owner: each caller passes
## its own key ("audiotron:<id>", "explainer:<id>") and the music stays ducked while ANY owner
## still holds it, so a movie that ends over an open AudiOtron (or the reverse) never brings
## the marimba back under the test beeps. An empty key is one shared anonymous owner.
func music_duck(on: bool, who: String = "") -> void:
	var key := who if who != "" else "_"
	if on:
		_duck_owners[key] = true
	else:
		_duck_owners.erase(key)
	var want := not _duck_owners.is_empty()
	if want == _music_ducked:
		return
	_music_ducked = want
	if _music == null:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	if want:
		_music_tween.tween_property(_music, "volume_db", -60.0, 0.4)
		_music_tween.tween_callback(func() -> void: _music.stream_paused = true)
	else:
		_music.stream_paused = false
		_music_tween.tween_property(_music, "volume_db", MUSIC_DB, 1.2)


## True while any owner holds the music ducked.
func is_music_ducked() -> bool:
	return _music_ducked


## Who is holding the duck right now (tests, debugging).
func music_duck_owners() -> Array:
	return _duck_owners.keys()


func is_music_playing() -> bool:
	return _music != null and _music.playing and not _music.stream_paused


func _music_play() -> void:
	if _music.stream != _music_stream:
		_music.stream = _music_stream
	if not _music.playing:
		_music.volume_db = -60.0 if _music_ducked else MUSIC_DB
		_music.play()
	_music.stream_paused = _music_ducked


## Worker thread: four bars of soft marimba arpeggio over a round bass, seamless loop.
func _build_music() -> void:
	var beat := 60.0 / MUSIC_BPM
	var bars := MUSIC_CHORDS.size()
	var n := int(round(bars * 4.0 * beat * MIX_RATE))
	var b := PackedFloat32Array()
	b.resize(n)
	for bi in bars:
		var chord: Array = MUSIC_CHORDS[bi]
		var t0 := bi * 4.0 * beat
		_pluck_wrap(b, t0, float(chord[0]), 0.55, 2.6, 1.6, 0.0)
		_pluck_wrap(b, t0 + 2.0 * beat, float(chord[0]) * 1.5, 0.3, 3.0, 1.2, 0.0)
		var notes: Array = chord[1]
		for k in 8:
			var amp := 0.32 if k % 2 == 0 else 0.22
			_pluck_wrap(b, t0 + k * beat * 0.5, float(notes[ARP[k]]), amp, 9.0, 0.7, 0.12)
	_music_samples = b


## A marimba-ish pluck (sine + a quiet two-octave partial) that wraps past the loop end.
func _pluck_wrap(b: PackedFloat32Array, start_s: float, f: float, amp: float, decay: float, dur_s: float, partial: float) -> void:
	var n := b.size()
	var i0 := int(start_s * MIX_RATE)
	var count := int(dur_s * MIX_RATE)
	for i in count:
		var t := float(i) / MIX_RATE
		var env := minf(1.0, t / 0.006) * exp(-t * decay)
		var v := sin(TAU * f * t) + partial * sin(TAU * f * 4.0 * t) * exp(-t * 18.0)
		var j := (i0 + i) % n
		b[j] += v * env * amp


## Stop every voice and drop the cached streams (called on quit so no playback outlives the tree).
func stop_all() -> void:
	for p: AudioStreamPlayer in _players:
		p.stop()
		p.stream = null
	_cache.clear()
	if _music != null:
		_music.stop()


func _exit_tree() -> void:
	stop_all()
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1


## Play a named sound. Unknown names print a warning and play "click".
func play(sound: StringName, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	var stream := get_stream(sound)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.pitch_scale = clampf(pitch_scale, 0.25, 4.0)
	p.volume_db = minf(volume_db, 0.0)
	p.play()


## Bell note at freq_hz (used for the musical audiogram: 250 Hz -> C4 ... 8 kHz -> C6).
func play_note(freq_hz: float, volume_db: float = 0.0) -> void:
	play(&"note", freq_hz / NOTE_BASE_HZ, volume_db)


## Map an audiometric frequency to a musical note: 250 Hz -> C4 (261.63) ... 8 kHz -> C6.
static func audiogram_note_hz(freq: int) -> float:
	var octaves := log(float(freq) / 250.0) / log(2.0)  # 0..5
	return 261.63 * pow(2.0, octaves * 2.0 / 5.0)


func get_stream(sound: StringName) -> AudioStreamWAV:
	if _cache.has(sound):
		return _cache[sound]
	var fn := "_gen_" + String(sound)
	if not has_method(fn):
		push_warning("Sfx: unknown sound " + String(sound))
		return get_stream(&"click") if sound != &"click" else null
	var samples: PackedFloat32Array = call(fn)
	var wav := _to_wav(samples)
	_cache[sound] = wav
	return wav


func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := pow(10.0, AudioSafety.SFX_PEAK_DBFS / 20.0) / peak
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


# ---------------------------------------------------------------- synthesis helpers

func _buf(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * MIX_RATE))
	return b


## Add a sine sweep with an exponential decay envelope.
func _tone(b: PackedFloat32Array, start_s: float, dur_s: float, f0: float, f1: float, amp: float, decay: float = 6.0, attack_s: float = 0.004, harmonics: Array = []) -> void:
	var i0 := int(start_s * MIX_RATE)
	var n := int(dur_s * MIX_RATE)
	var phase := 0.0
	for i in n:
		if i0 + i >= b.size():
			break
		var t := float(i) / MIX_RATE
		var k := float(i) / maxf(1.0, n - 1)
		var f := lerpf(f0, f1, k)
		phase += TAU * f / MIX_RATE
		var env := minf(1.0, t / attack_s) * exp(-decay * t) * (1.0 - pow(k, 8.0))
		var v := sin(phase)
		for h: Array in harmonics:
			v += float(h[1]) * sin(phase * float(h[0]))
		b[i0 + i] += v * amp * env


func _noise(b: PackedFloat32Array, start_s: float, dur_s: float, amp: float, decay: float = 20.0, smooth: float = 0.0) -> void:
	var i0 := int(start_s * MIX_RATE)
	var n := int(dur_s * MIX_RATE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var prev := 0.0
	for i in n:
		if i0 + i >= b.size():
			break
		var t := float(i) / MIX_RATE
		var v := rng.randf_range(-1.0, 1.0)
		prev = lerpf(v, prev, smooth)
		b[i0 + i] += prev * amp * exp(-decay * t)


# ---------------------------------------------------------------- sounds

func _gen_click() -> PackedFloat32Array:
	var b := _buf(0.05)
	_noise(b, 0.0, 0.01, 0.6, 300.0)
	_tone(b, 0.0, 0.05, 1800.0, 1400.0, 0.7, 80.0)
	return b


func _gen_blip() -> PackedFloat32Array:
	var b := _buf(0.08)
	_tone(b, 0.0, 0.08, 880.0, 990.0, 1.0, 35.0, 0.003, [[2.0, 0.2]])
	return b


func _gen_thunk() -> PackedFloat32Array:
	var b := _buf(0.12)
	_tone(b, 0.0, 0.12, 180.0, 70.0, 1.0, 30.0)
	_noise(b, 0.0, 0.03, 0.3, 120.0, 0.6)
	return b


func _gen_stamp() -> PackedFloat32Array:
	var b := _buf(0.22)
	_tone(b, 0.0, 0.2, 130.0, 55.0, 1.0, 22.0)
	_noise(b, 0.0, 0.08, 0.7, 60.0, 0.75)
	_tone(b, 0.02, 0.1, 900.0, 600.0, 0.15, 50.0)
	return b


func _gen_ding() -> PackedFloat32Array:
	var b := _buf(0.9)
	_tone(b, 0.0, 0.9, 1318.5, 1318.5, 1.0, 4.5, 0.002, [[2.0, 0.35], [3.01, 0.12]])
	return b


func _gen_note() -> PackedFloat32Array:
	var b := _buf(0.7)
	_tone(b, 0.0, 0.7, NOTE_BASE_HZ, NOTE_BASE_HZ, 1.0, 5.0, 0.003, [[2.0, 0.3], [4.0, 0.08]])
	return b


func _gen_boing() -> PackedFloat32Array:
	var b := _buf(0.55)
	var phase := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var f := 180.0 + 260.0 * (1.0 - exp(-t * 9.0)) + 40.0 * sin(TAU * 14.0 * t) * exp(-t * 3.0)
		phase += TAU * f / MIX_RATE
		b[i] = sin(phase) * exp(-t * 5.0) * minf(1.0, t / 0.005)
	return b


func _gen_pop() -> PackedFloat32Array:
	var b := _buf(0.09)
	_tone(b, 0.0, 0.09, 700.0, 220.0, 1.0, 30.0)
	return b


func _gen_whoosh() -> PackedFloat32Array:
	var b := _buf(0.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lp := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var k := t / 0.4
		var cutoff := lerpf(0.05, 0.5, sin(k * PI))
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), cutoff)
		b[i] = lp * sin(k * PI)
	return b


func _gen_kaching() -> PackedFloat32Array:
	var b := _buf(0.8)
	_noise(b, 0.0, 0.06, 0.5, 60.0, 0.3)
	_tone(b, 0.05, 0.75, 2093.0, 2093.0, 0.8, 5.0, 0.002, [[2.0, 0.3]])
	_tone(b, 0.12, 0.65, 2637.0, 2637.0, 0.7, 5.0, 0.002, [[2.0, 0.3]])
	return b


func _gen_sad_trombone() -> PackedFloat32Array:
	var b := _buf(1.3)
	var notes := [[0.0, 392.0], [0.28, 370.0], [0.56, 349.2], [0.84, 329.6]]
	for nt: Array in notes:
		var dur := 0.45 if float(nt[0]) < 0.8 else 0.46
		_tone(b, float(nt[0]), dur, float(nt[1]), float(nt[1]) * (0.97 if float(nt[0]) > 0.8 else 1.0), 0.6, 2.5, 0.03, [[2.0, 0.5], [3.0, 0.3], [4.0, 0.15]])
	return b


func _gen_squeak() -> PackedFloat32Array:
	var b := _buf(0.16)
	_tone(b, 0.0, 0.16, 1700.0, 2500.0, 1.0, 8.0, 0.01, [[2.0, 0.15]])
	return b


func _gen_fanfare() -> PackedFloat32Array:
	var b := _buf(1.0)
	var notes := [523.25, 659.25, 783.99, 1046.5]
	for i in notes.size():
		_tone(b, i * 0.12, 1.0 - i * 0.12, notes[i], notes[i], 0.7, 3.5, 0.004, [[2.0, 0.3], [3.0, 0.1]])
	return b


func _gen_chirp() -> PackedFloat32Array:
	var b := _buf(0.1)
	_tone(b, 0.0, 0.1, 1200.0, 1650.0, 1.0, 18.0, 0.004, [[2.0, 0.1]])
	return b


func _gen_pen() -> PackedFloat32Array:
	var b := _buf(0.25)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bp := 0.0
	var prev := 0.0
	for i in b.size():
		var t := float(i) / MIX_RATE
		var v := rng.randf_range(-1.0, 1.0)
		bp = lerpf(bp, v - prev, 0.35)
		prev = v
		b[i] = bp * (0.6 + 0.4 * sin(TAU * 18.0 * t)) * minf(1.0, t / 0.02) * exp(-t * 6.0)
	return b


func _gen_door() -> PackedFloat32Array:
	var b := _buf(0.35)
	_tone(b, 0.0, 0.35, 90.0, 50.0, 1.0, 10.0)
	_noise(b, 0.0, 0.12, 0.4, 25.0, 0.85)
	return b


func _gen_sparkle() -> PackedFloat32Array:
	var b := _buf(0.7)
	var notes := [1568.0, 2093.0, 2637.0, 3136.0]
	for i in notes.size():
		_tone(b, i * 0.07, 0.5, notes[i], notes[i], 0.5, 7.0, 0.002)
	return b


func _gen_error() -> PackedFloat32Array:
	var b := _buf(0.25)
	_tone(b, 0.0, 0.11, 330.0, 320.0, 0.8, 4.0, 0.004, [[3.0, 0.2]])
	_tone(b, 0.12, 0.12, 262.0, 255.0, 0.8, 4.0, 0.004, [[3.0, 0.2]])
	return b

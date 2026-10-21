class_name ToneGenerator
extends Node
## ToneGenerator: safe synthesized test tones (builder A). CONTRACTS.md §1.3 and §4.8.
##  - AudioStreamGenerator (44.1 kHz) on the "Tones" bus, whose hard limiter sits at -12 dBFS.
##  - Right ear -> right channel only, left ear -> left channel only.
##  - Stimuli: pure (steady), pulsed (225 ms on / 225 ms off), warble (5 Hz FM, +-5 %).
##  - 25 ms raised-cosine on/off ramps (no clicks); level changes glide over 15 ms.
##  - Level ALWAYS goes through AudioSafety.hl_to_peak() and every sample through
##    AudioSafety.clamp_sample(): 0 dB HL ~ -71 dBFS RMS, never above -12 dBFS peak.
## render(frames) is pure DSP (no audio server), so tests can measure exactly what would play.
## Visual indicators never depend on this node: the game is fully playable without sound.
## (v3) Narrow-band masking noise for the OTHER ear (start_masker()): white noise through a
## 1/3-octave band-pass at the test frequency, level from AudioSafety.masker_to_rms() and every
## sample through AudioSafety.clamp_masker_sample() (quiet: a hiss, never a blast). 50 ms ramps.
## (v3) Bone channel (`bone`): the oscillator shakes the whole skull (interaural attenuation 0), so a
## bone tone plays in the test ear's channel AND, BONE_CROSS_DB softer, in the other one: you can
## hear why the other cochlea answers. Same safe mapping and clamp; air tones stay one-channel.

enum Stimulus { PURE, PULSED, WARBLE }

const STIMULUS_NAMES: Array[String] = ["TONE", "PULSED", "WARBLE"]
const MIX_RATE := 44100.0
const RAMP_S := 0.025
const LEVEL_GLIDE_S := 0.015
const PULSE_PERIOD_S := 0.45
const PULSE_ON_S := 0.225
const WARBLE_RATE_HZ := 5.0
const WARBLE_DEPTH := 0.05

var ear: String = "right"
var freq: float = 1000.0
var level_hl: float = 0.0
var stimulus: int = Stimulus.PURE
## Kept for older callers: true = pulsed.
var pulsed: bool:
	get:
		return stimulus == Stimulus.PULSED
	set(v):
		stimulus = Stimulus.PULSED if v else Stimulus.PURE

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0       ## carrier phase, cycles 0..1
var _lfo := 0.0         ## warble LFO phase, cycles 0..1
var _ramp := 0.0        ## on/off ramp position 0..1
var _target := 0.0      ## 1 while the tone is on
var _amp := 0.0         ## smoothed peak amplitude
var _t_on := 0.0        ## seconds since the tone started (pulse clock)

# ---- v3 bone channel
const BONE_CROSS_DB := -10.0
## true while the tone goes to the bone oscillator (set before start_tone()).
var bone: bool = false

# ---- v3 masker
const MASKER_RAMP_S := 0.05
const MASKER_BW_OCT := 1.0 / 3.0
var masker_on: bool = false
var masker_ear: String = "left"
var masker_freq: float = 1000.0
var masker_db: float = 0.0
var _m_ramp := 0.0
var _m_gain := 0.0       ## smoothed noise gain (target RMS / the filter's noise RMS)
var _m_norm := 1.0       ## 1 / RMS of the band-pass output for unit uniform noise
var _m_b0 := 0.0
var _m_a1 := 0.0
var _m_a2 := 0.0
var _m_x1 := 0.0
var _m_x2 := 0.0
var _m_y1 := 0.0
var _m_y2 := 0.0
var _m_rng := RandomNumberGenerator.new()

## The streams of freed generators stay alive a little longer (core/INTEGRATION_NOTES.md, "the
## headless exit hang"): an AudioStreamGeneratorPlayback points at its stream without holding it,
## and a player freed while playing is mixed once more (its fade-out) after the stream is gone; that
## read of freed memory could spin the audio thread forever. Same fix as SpeechVoice.
const RETIRED_KEEP := 16
static var _retired: Array[AudioStream] = []


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _player != null and _player.stream != null:
		_retired.append(_player.stream)
		while _retired.size() > RETIRED_KEEP:
			_retired.pop_front()


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.1
	_player.stream = gen
	_player.bus = AudioSafety.TONES_BUS if AudioServer.get_bus_index(AudioSafety.TONES_BUS) >= 0 else &"Master"
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func start_tone(p_ear: String, p_freq: float, p_level_hl: float) -> void:
	if _target <= 0.0 and _ramp <= 0.0:
		_t_on = 0.0
		_lfo = 0.0
		_amp = AudioSafety.hl_to_peak(p_level_hl)
	ear = p_ear
	freq = p_freq
	level_hl = p_level_hl
	_target = 1.0


func stop_tone() -> void:
	_target = 0.0


func set_level(p_level_hl: float) -> void:
	level_hl = p_level_hl


func set_stimulus(s: int) -> void:
	stimulus = clampi(s, Stimulus.PURE, Stimulus.WARBLE)


func is_on() -> bool:
	return _target > 0.0


## (v3) Masking noise on in one ear (the non-test ear) at a frequency and masker level (dB EM).
func start_masker(p_ear: String, p_freq: float, p_db_em: float) -> void:
	if not masker_on and _m_ramp <= 0.0:
		_m_gain = AudioSafety.masker_to_rms(p_db_em) * _m_norm
	masker_ear = p_ear
	set_masker(p_freq, p_db_em)
	masker_on = true


func set_masker(p_freq: float, p_db_em: float) -> void:
	if not is_equal_approx(p_freq, masker_freq) or _m_b0 == 0.0:
		masker_freq = p_freq
		_design_band(p_freq)
	masker_db = p_db_em


func stop_masker() -> void:
	masker_on = false


## RBJ band-pass (constant 0 dB peak), 1/3 octave wide, and its noise normalisation: uniform
## noise (RMS 1/sqrt(3)) through it comes out at about sqrt(pi * BW / fs) of that.
func _design_band(f: float) -> void:
	var w0 := TAU * clampf(f, 100.0, 16000.0) / MIX_RATE
	var alpha := sin(w0) * sinh(log(2.0) / 2.0 * MASKER_BW_OCT * w0 / sin(w0))
	var a0 := 1.0 + alpha
	_m_b0 = alpha / a0
	_m_a1 = -2.0 * cos(w0) / a0
	_m_a2 = (1.0 - alpha) / a0
	var bw_hz := f * (pow(2.0, MASKER_BW_OCT / 2.0) - pow(2.0, -MASKER_BW_OCT / 2.0))
	var out_rms := sqrt(1.0 / 3.0) * sqrt(PI * bw_hz / MIX_RATE)
	_m_norm = 1.0 / maxf(out_rms, 1e-4)


## Peak amplitude the generator is currently allowed to output (0..1).
func current_peak() -> float:
	return AudioSafety.hl_to_peak(level_hl)


## Synthesize the next `frames` stereo frames (x = left, y = right). Advances the generator.
func render(frames: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames)  # zero-filled
	if masker_on or _m_ramp > 0.0:
		_render_masker(out)
	if _target <= 0.0 and _ramp <= 0.0:
		return out  # no tone: nothing more to synthesize
	var target_amp := AudioSafety.hl_to_peak(level_hl)
	var ramp_step := 1.0 / (RAMP_S * MIX_RATE)
	var glide := 1.0 - exp(-1.0 / (LEVEL_GLIDE_S * MIX_RATE))
	var dt := 1.0 / MIX_RATE
	var right := ear == "right"
	var cross := db_to_linear(BONE_CROSS_DB) if bone else 0.0
	for i in frames:
		_ramp = move_toward(_ramp, _target, ramp_step)
		if _ramp <= 0.0 and _target <= 0.0:
			continue  # the tone has ramped out: out[i] already holds the masker (or silence)
		_amp += (target_amp - _amp) * glide
		var env := 0.5 - 0.5 * cos(PI * _ramp)  # raised cosine
		if stimulus == Stimulus.PULSED:
			env *= _pulse_env(fmod(_t_on, PULSE_PERIOD_S))
		var f := freq
		if stimulus == Stimulus.WARBLE:
			f *= 1.0 + WARBLE_DEPTH * sin(TAU * _lfo)
			_lfo = fmod(_lfo + WARBLE_RATE_HZ * dt, 1.0)
		var v := AudioSafety.clamp_sample(sin(TAU * _phase) * _amp * env)
		if cross > 0.0:
			# bone: the far cochlea gets it too, softer, on top of any masking noise there
			var c := v * cross
			out[i] = Vector2(AudioSafety.clamp_sample(out[i].x + c), v) if right else Vector2(v, AudioSafety.clamp_sample(out[i].y + c))
		else:
			out[i] = Vector2(out[i].x, v) if right else Vector2(v, out[i].y)
		_phase = fmod(_phase + f * dt, 1.0)
		_t_on += dt
	return out


## (v3) Add the masking noise into its ear's channel of out.
func _render_masker(out: PackedVector2Array) -> void:
	var target_gain := AudioSafety.masker_to_rms(masker_db) * _m_norm if masker_on else _m_gain
	var ramp_step := 1.0 / (MASKER_RAMP_S * MIX_RATE)
	var glide := 1.0 - exp(-1.0 / (LEVEL_GLIDE_S * MIX_RATE))
	var right := masker_ear == "right"
	var goal := 1.0 if masker_on else 0.0
	for i in out.size():
		_m_ramp = move_toward(_m_ramp, goal, ramp_step)
		_m_gain += (target_gain - _m_gain) * glide
		var x := _m_rng.randf_range(-1.0, 1.0)
		var y := _m_b0 * (x - _m_x2) - _m_a1 * _m_y1 - _m_a2 * _m_y2
		_m_x2 = _m_x1
		_m_x1 = x
		_m_y2 = _m_y1
		_m_y1 = y
		var env := 0.5 - 0.5 * cos(PI * _m_ramp)
		var v := AudioSafety.clamp_masker_sample(y * _m_gain * env)
		out[i] = Vector2(out[i].x, v) if right else Vector2(v, out[i].y)


## Raised-cosine gate for one pulse cycle (t in 0..PULSE_PERIOD_S).
static func _pulse_env(t: float) -> float:
	if t >= PULSE_ON_S:
		return 0.0
	var edge := minf(t, PULSE_ON_S - t)
	if edge >= RAMP_S:
		return 1.0
	return 0.5 - 0.5 * cos(PI * edge / RAMP_S)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	_playback.push_buffer(render(frames))

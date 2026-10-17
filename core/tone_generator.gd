class_name ToneGenerator
extends Node
## ToneGenerator: safe synthesized test tones (builder A). CONTRACTS.md §1.3 and §4.8.
##  - AudioStreamGenerator (44.1 kHz) on the "Tones" bus, whose hard limiter sits at -12 dBFS.
##  - Right ear -> right channel only, left ear -> left channel only.
##  - Stimuli: pure (steady), pulsed (225 ms on / 225 ms off), warble (5 Hz FM, +-5 %).
##  - 25 ms raised-cosine on/off ramps (no clicks); level changes glide over 15 ms.
##  - Level ALWAYS goes through AudioSafety.hl_to_peak() and every sample through
##    AudioSafety.clamp_sample(): 0 dB HL ~ -75 dBFS RMS, never above -12 dBFS peak.
## render(frames) is pure DSP (no audio server), so tests can measure exactly what would play.
## Visual indicators never depend on this node: the game is fully playable without sound.

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


## Peak amplitude the generator is currently allowed to output (0..1).
func current_peak() -> float:
	return AudioSafety.hl_to_peak(level_hl)


## Synthesize the next `frames` stereo frames (x = left, y = right). Advances the generator.
func render(frames: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(frames)  # zero-filled
	if _target <= 0.0 and _ramp <= 0.0:
		return out  # silent: nothing to synthesize
	var target_amp := AudioSafety.hl_to_peak(level_hl)
	var ramp_step := 1.0 / (RAMP_S * MIX_RATE)
	var glide := 1.0 - exp(-1.0 / (LEVEL_GLIDE_S * MIX_RATE))
	var dt := 1.0 / MIX_RATE
	var right := ear == "right"
	for i in frames:
		_ramp = move_toward(_ramp, _target, ramp_step)
		if _ramp <= 0.0 and _target <= 0.0:
			out[i] = Vector2.ZERO
			continue
		_amp += (target_amp - _amp) * glide
		var env := 0.5 - 0.5 * cos(PI * _ramp)  # raised cosine
		if stimulus == Stimulus.PULSED:
			env *= _pulse_env(fmod(_t_on, PULSE_PERIOD_S))
		var f := freq
		if stimulus == Stimulus.WARBLE:
			f *= 1.0 + WARBLE_DEPTH * sin(TAU * _lfo)
			_lfo = fmod(_lfo + WARBLE_RATE_HZ * dt, 1.0)
		var v := AudioSafety.clamp_sample(sin(TAU * _phase) * _amp * env)
		out[i] = Vector2(0.0, v) if right else Vector2(v, 0.0)
		_phase = fmod(_phase + f * dt, 1.0)
		_t_on += dt
	return out


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

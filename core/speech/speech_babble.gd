class_name SpeechBabble
extends RefCounted
## SpeechBabble: the party noise of Day 5's Party Noise Test (CONTRACTS.md §9.16, docs/CHAPTER5.md §5).
## An 8 s loop of four murmuring talkers, made cheaply from SpeechVoice's cached murmur syllables
## (no sine synthesis per sample): each talker resamples them to its own pitch (TALKER_F0_HZ against
## the murmur's SpeechVoice.F0_HZ) with its own seeded start, syllable order, pauses and loudness
## (seed 7). The four are summed, each talker's last word wraps onto the start so the loop has no
## seam, and the whole is scaled to unit RMS (peaks capped at CREST). SpeechVoice plays it on the masker's safety path
## (AudioSafety.masker_to_rms() and clamp_masker_sample()), so it is never loud.
## A recording at RECORDING_PATH replaces the synthesis (SpeechVoice.wav_to_mono, unit RMS the same way).
## Pure DSP, no audio server: tests measure exactly what would play. Nothing depends on hearing it:
## the screen draws the party.

const LOOP_S := 8.0
## The four talkers' pitches (Hz); the murmur's own is SpeechVoice.F0_HZ.
const TALKER_F0_HZ: Array[float] = [105.0, 130.0, 190.0, 225.0]
const SEED := 7
const RECORDING_PATH := "res://assets/speech/babble/babble.wav"
## Syllables of the murmur the talkers draw from (SpeechVoice.murmur(SOURCE_SYLLABLES, seed)).
const SOURCE_SYLLABLES := 3
## A talker's "word": 1-3 syllables with short joins, then a pause (seconds).
const WORD_SYLLABLES := Vector2i(1, 3)
const JOIN_S := Vector2(0.01, 0.05)
const PAUSE_S := Vector2(0.08, 0.45)
## When each talker first speaks (seconds into the loop).
const START_S := Vector2(0.0, 0.6)
## Each talker's loudness against the others, so the four never merge into one voice.
const TALKER_GAIN := Vector2(0.7, 1.0)
## Peaks are capped near this many times the RMS (about 12 dB), so the masker's ceiling clips less
## of the party at the louder dial settings.
const CREST := 4.0

static var _loop := PackedFloat32Array()


## The babble loop (mono, SpeechVoice.MIX_RATE, unit RMS): the recording when there is one, else the
## synthesis. Built once, then cached.
static func loop() -> PackedFloat32Array:
	if _loop.is_empty():
		_loop = from_recording()
		if _loop.is_empty():
			_loop = synthesize()
	return _loop


## Has the loop been built (so the first party sentence needs no wait)?
static func is_built() -> bool:
	return not _loop.is_empty()


## Forget the cached loop (tests).
static func clear_cache() -> void:
	_loop = PackedFloat32Array()


## Samples in the synthesized loop.
static func loop_frames() -> int:
	return int(LOOP_S * SpeechVoice.MIX_RATE)


## The recording at RECORDING_PATH at unit RMS, or empty when there is none (or it can't be decoded).
static func from_recording() -> PackedFloat32Array:
	if not ResourceLoader.exists(RECORDING_PATH):
		return PackedFloat32Array()
	var stream: Variant = load(RECORDING_PATH)
	var pcm := SpeechVoice.wav_to_mono(stream as AudioStreamWAV) if stream is AudioStreamWAV else PackedFloat32Array()
	return unit_rms(pcm)


## Four talkers of murmur, LOOP_S long, unit RMS. The same seed always gives the same loop.
static func synthesize(seed_value: int = SEED) -> PackedFloat32Array:
	var n := loop_frames()
	var rate := SpeechVoice.MIX_RATE
	var src := SpeechVoice.murmur(SOURCE_SYLLABLES, seed_value)
	var syl := int(SpeechVoice.SYLLABLE_S * rate)
	var stride := syl + int(SpeechVoice.SYLLABLE_GAP_S * rate)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tracks: Array[PackedFloat32Array] = []
	for f0: float in TALKER_F0_HZ:
		var gain := rng.randf_range(TALKER_GAIN.x, TALKER_GAIN.y)
		var sylls: Array[PackedFloat32Array] = []
		for k in SOURCE_SYLLABLES:
			sylls.append(_resampled(src, k * stride, syl, f0 / SpeechVoice.F0_HZ, gain))
		var track := _silence(int(rng.randf_range(START_S.x, START_S.y) * rate))
		while track.size() < n:
			var words := rng.randi_range(WORD_SYLLABLES.x, WORD_SYLLABLES.y)
			for w in words:
				track.append_array(sylls[rng.randi_range(0, sylls.size() - 1)])
				if w < words - 1:
					track.append_array(_silence(int(rng.randf_range(JOIN_S.x, JOIN_S.y) * rate)))
			track.append_array(_silence(int(rng.randf_range(PAUSE_S.x, PAUSE_S.y) * rate)))
		tracks.append(track)
	# the four talkers together; each one's overflow wraps onto the start (a seamless loop)
	var out := _silence(n)
	var t0 := tracks[0]
	var t1 := tracks[1]
	var t2 := tracks[2]
	var t3 := tracks[3]
	for i in n:
		out[i] = t0[i] + t1[i] + t2[i] + t3[i]
	for t: PackedFloat32Array in tracks:
		for i in range(n, t.size()):
			out[i - n] += t[i]
	# scale to unit RMS with the few tall murmur peaks capped at CREST: the cap's energy is
	# measured first, so one writing pass lands on unit RMS exactly
	var k := 1.0 / maxf(rms(out), 1e-9)
	var capped := 0.0
	for x: float in out:
		capped += minf(x * x * k * k, CREST * CREST)
	var k2 := 1.0 / sqrt(maxf(capped / float(n), 1e-18))
	for i in n:
		out[i] = clampf(out[i] * k, -CREST, CREST) * k2
	return out


## The loop's RMS over every sample (babble is continuous noise, so its pauses count too).
static func rms(pcm: PackedFloat32Array) -> float:
	if pcm.is_empty():
		return 0.0
	var sum := 0.0
	for x: float in pcm:
		sum += x * x
	return sqrt(sum / float(pcm.size()))


## `pcm` scaled to unit RMS (empty stays empty; silence stays silence).
static func unit_rms(pcm: PackedFloat32Array) -> PackedFloat32Array:
	var r := rms(pcm)
	if r <= 1e-9:
		return pcm
	var k := 1.0 / r
	var out := PackedFloat32Array()
	out.resize(pcm.size())
	for i in pcm.size():
		out[i] = pcm[i] * k
	return out


## One syllable of `src` (from `start`, `length` samples) read `ratio` times faster: pitch up by
## `ratio`, length down by it (linear interpolation), times `gain`.
static func _resampled(src: PackedFloat32Array, start: int, length: int, ratio: float, gain: float) -> PackedFloat32Array:
	var end := mini(start + length, src.size()) - 1
	var n := maxi(0, int(float(end - start) / ratio))
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var x := float(start) + float(i) * ratio
		var j := int(x)
		out[i] = lerpf(src[j], src[mini(j + 1, end)], x - float(j)) * gain
	return out


static func _silence(n: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(maxi(0, n))
	out.fill(0.0)
	return out

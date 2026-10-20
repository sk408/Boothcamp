extends TestCase
## (Day 5) The party noise of the Party Noise Test (CONTRACTS.md §9.16, §9.24): SpeechBabble's loop of
## four murmuring talkers. It builds fast enough for level start, sits at unit RMS with its peaks
## capped, keeps going (a party, not a few voices with gaps), and replays exactly from its seed. Then
## how SpeechVoice plays it: on the masker's mapping (at SNR 0 the party has the talker's RMS), its
## peaks and the mix's capped, "both" in both channels while "right" and "left" stay one-eared, and
## the party stopping on stop_babble(), a pause and leaving the tree.


func after_each() -> void:
	SpeechBabble.clear_cache()


func test_the_loop_builds_fast() -> void:
	SpeechBabble.clear_cache()
	SpeechVoice._murmur_cache.erase("%d:%d" % [SpeechBabble.SOURCE_SYLLABLES, SpeechBabble.SEED])
	assert_false(SpeechBabble.is_built())
	var t0 := Time.get_ticks_usec()
	var loop := SpeechBabble.loop()
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	assert_true(ms < 150.0, "the babble loop builds in under 150 ms headless (%.1f ms)" % ms)
	assert_true(SpeechBabble.is_built())
	assert_eq(loop.size(), SpeechBabble.loop_frames(), "LOOP_S long")
	assert_eq(loop.size(), int(SpeechBabble.LOOP_S * SpeechVoice.MIX_RATE))
	assert_true(SpeechBabble.loop() == loop, "built once, then cached")


func test_unit_rms_and_capped_peaks() -> void:
	var loop := SpeechBabble.loop()
	assert_near(SpeechBabble.rms(loop), 1.0, 0.001, "unit RMS over the whole loop")
	var peak := 0.0
	for x: float in loop:
		peak = maxf(peak, absf(x))
	assert_true(peak <= SpeechBabble.CREST * 1.05, "peaks capped near CREST (%.2f)" % peak)
	assert_true(peak > 2.0, "but it is still speech-like, not flat noise (%.2f)" % peak)


## Four talkers keep the party going: few 50 ms windows drop 12 dB under the loop's RMS, none
## stands 6 dB over it.
func test_the_party_keeps_going() -> void:
	var loop := SpeechBabble.loop()
	var win := int(0.05 * SpeechVoice.MIX_RATE)
	var quiet := 0
	var windows := 0
	var i := 0
	while i + win <= loop.size():
		var r := SpeechBabble.rms(loop.slice(i, i + win))
		quiet += int(r < 0.25)
		assert_true(r < 2.0, "no window stands out (%.2f at %.2f s)" % [r, float(i) / SpeechVoice.MIX_RATE])
		windows += 1
		i += win
	assert_true(float(quiet) / float(windows) <= 0.05, "the party rarely dips (%d of %d windows)" % [quiet, windows])
	# the start is as busy as the end: the talkers' overflow wraps onto it (a seamless loop)
	var half := int(0.5 * SpeechVoice.MIX_RATE)
	var head := SpeechBabble.rms(loop.slice(0, half))
	var tail := SpeechBabble.rms(loop.slice(loop.size() - half))
	assert_between(head / tail, 0.5, 2.0, "head %.2f, tail %.2f" % [head, tail])


func test_the_same_seed_replays() -> void:
	var a := SpeechBabble.synthesize()
	assert_true(a == SpeechBabble.synthesize(), "seed 7 always gives the same loop")
	assert_true(a == SpeechBabble.synthesize(SpeechBabble.SEED))
	assert_false(a == SpeechBabble.synthesize(SpeechBabble.SEED + 1), "another seed, another party")
	assert_eq(SpeechBabble.TALKER_F0_HZ.size(), 4, "four talkers")


func test_recording_and_helpers() -> void:
	if not ResourceLoader.exists(SpeechBabble.RECORDING_PATH):
		assert_eq(SpeechBabble.from_recording(), PackedFloat32Array(), "no recording: the synthesis plays")
	assert_eq(SpeechBabble.unit_rms(PackedFloat32Array()), PackedFloat32Array())
	var silence := PackedFloat32Array([0.0, 0.0, 0.0])
	assert_eq(SpeechBabble.unit_rms(silence), silence, "silence stays silence")
	var scaled := SpeechBabble.unit_rms(PackedFloat32Array([0.5, -0.5, 0.5, -0.5]))
	assert_near(SpeechBabble.rms(scaled), 1.0, 0.0001)
	assert_eq(SpeechBabble.rms(PackedFloat32Array()), 0.0)


# ---------------------------------------------------------------- SpeechVoice plays the party (§9.16)

func _voice() -> SpeechVoice:
	var v := SpeechVoice.new()
	add_node(v)
	return v


static func _rms(out: PackedVector2Array, right: bool) -> float:
	var sum := 0.0
	for x: Vector2 in out:
		var s := x.y if right else x.x
		sum += s * s
	return sqrt(sum / maxf(1.0, float(out.size())))


static func _db(ratio: float) -> float:
	return 20.0 * log(maxf(ratio, 1e-12)) / log(10.0)


## The party sits on the masker's mapping, BABBLE_TRIM_DB down: at SNR 0 it plays at the words' RMS.
func test_babble_level_on_the_masker_mapping() -> void:
	var v := _voice()
	v.start_babble("both", 65)
	assert_true(v.babble_ready(), "the loop is built by start_babble")
	assert_true(v.is_babbling())
	v.render(int(0.1 * SpeechVoice.MIX_RATE))   # past the fade-in
	var out := v.render(SpeechBabble.loop().size())   # the whole loop once
	for right: bool in [true, false]:
		var r := _rms(out, right)
		assert_near(_db(r / AudioSafety.masker_to_rms(60.0)), 0.0, 1.0, "within 1 dB of masker_to_rms(db - 5)")
		assert_near(_db(r / SpeechVoice.babble_rms(65)), 0.0, 1.0)
	# a word at talker 65 (SNR 0): its RMS over the voiced part is speech_to_rms(65)
	var w := _voice()
	var it: Dictionary = SpeechMaterial.items("party_1")[0]
	var dur := w.play_item("both", "__no_recordings__", it, 65.0)
	var word := w.render(int(dur * SpeechVoice.MIX_RATE))
	var sum := 0.0
	var n := 0
	for x: Vector2 in word:
		if absf(x.y) > 1e-6:
			sum += x.y * x.y
			n += 1
	var word_rms := sqrt(sum / maxf(1.0, float(n)))
	assert_near(_db(_rms(out, true) / word_rms), 0.0, 1.0, "SNR 0: the party at the talker's RMS")


## Peaks: the babble never passes the masker's ceiling, and the mix (talker 90 at SNR 0, the worst
## case of the test, and the dial's top) never passes -12 dBFS.
func test_babble_and_mix_peaks_capped() -> void:
	var it: Dictionary = SpeechMaterial.items("party_1")[5]
	for talker: int in [90, SpeechRules.MAX_DB]:
		var v := _voice()
		v.start_babble("both", talker)
		var alone := v.render(int(0.5 * SpeechVoice.MIX_RATE))
		for x: Vector2 in alone:
			assert_true(absf(x.x) <= AudioSafety.masker_ceiling() + 1e-6 and absf(x.y) <= AudioSafety.masker_ceiling() + 1e-6,
				"babble alone under MASKER_CEILING_DBFS")
		var dur := v.play_item("both", "__no_recordings__", it, float(talker))
		var mix := v.render(int(dur * SpeechVoice.MIX_RATE) + 200)
		var peak := 0.0
		for x: Vector2 in mix:
			peak = maxf(peak, maxf(absf(x.x), absf(x.y)))
		assert_true(peak > AudioSafety.masker_ceiling() * 0.5, "both play (%.4f)" % peak)
		assert_true(peak <= AudioSafety.peak_ceiling() + 1e-6, "the mix never above -12 dBFS at %d" % talker)


## play_item: "both" writes both channels (the deliberate change); "right" and "left" only theirs.
## The babble follows its own ear the same way.
func test_both_and_one_ear() -> void:
	var it: Dictionary = SpeechMaterial.items("party_1")[0]
	for e: String in ["both", "right", "left"]:
		var v := _voice()
		var dur := v.play_item(e, "__no_recordings__", it, 70.0)
		var out := v.render(int(dur * SpeechVoice.MIX_RATE))
		var r := _rms(out, true)
		var l := _rms(out, false)
		match e:
			"both":
				assert_true(r > 1e-4 and l > 1e-4, "both channels")
				assert_near(r, l, 1e-7, "the same mix in each")
			"right":
				assert_true(r > 1e-4 and l == 0.0, "right only")
			"left":
				assert_true(l > 1e-4 and r == 0.0, "left only")
		var b := _voice()
		b.start_babble(e, 60)
		var party := b.render(4410)
		assert_eq(_rms(party, true) > 0.0, e != "left", "babble right channel for %s" % e)
		assert_eq(_rms(party, false) > 0.0, e != "right", "babble left channel for %s" % e)


## The party stops: stop_babble() fades it out, set_babble() moves it, and leaving the tree or a
## pause cuts it at once.
func test_babble_stops() -> void:
	var v := _voice()
	v.start_babble("both", 60)
	v.render(2205)
	v.set_babble(40)
	assert_eq(v.babble_db, 40)
	v.render(22050)
	var quieter := _rms(v.render(22050), true)
	assert_near(_db(quieter / SpeechVoice.babble_rms(40)), 0.0, 2.0, "set_babble steps the party")
	v.stop_babble()
	v.render(int(SpeechVoice.NOISE_RAMP_S * SpeechVoice.MIX_RATE) + 10)
	assert_false(v.is_babbling(), "faded out")
	assert_eq(_rms(v.render(2205), true), 0.0, "silent")
	# a pause cuts it
	v.start_babble("both", 60)
	v.render(2205)
	tree.paused = true
	var cut := not v.is_babbling()
	tree.paused = false
	assert_true(cut, "the pause menu stops the party")
	assert_eq(_rms(v.render(2205), true), 0.0)
	# leaving the tree cuts it
	v.start_babble("both", 60)
	v.render(2205)
	v.get_parent().remove_child(v)
	assert_false(v.is_babbling(), "exit stops the party")
	v.free()
	# Day 3's voice never babbles
	var d3 := _voice()
	d3.play_item("right", "spondee_a", {"id": "__murmur_test", "text": "rainbow", "parts": ["rain", "bow"]}, 50.0)
	assert_false(d3.is_babbling())

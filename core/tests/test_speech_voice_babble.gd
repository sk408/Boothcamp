extends TestCase
## (Day 5) The party noise of the Party Noise Test (CONTRACTS.md §9.16, §9.24): SpeechBabble's loop of
## four murmuring talkers. It builds fast enough for level start, sits at unit RMS with its peaks
## capped, keeps going (a party, not a few voices with gaps), and replays exactly from its seed. The
## checks of how SpeechVoice plays it (the masker's safety path, "both" channels, stopping) join this
## file with the PARTY mode's voice step.


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

extends TestCase
## Playback safety: simulated dB HL never becomes a loud sound.


func test_zero_hl_is_about_minus_75_dbfs() -> void:
	assert_near(AudioSafety.hl_to_dbfs(0), -75.0, 0.01)


func test_peak_never_exceeds_ceiling() -> void:
	var ceiling := AudioSafety.peak_ceiling()
	assert_near(linear_to_db(ceiling), -12.0, 0.01)
	for hl in range(-10, 141, 5):
		assert_true(AudioSafety.hl_to_peak(hl) <= ceiling + 1e-6, "hl %d too loud" % hl)


func test_monotonic_until_ceiling() -> void:
	var prev := 0.0
	for hl in range(-10, 120, 5):
		var p := AudioSafety.hl_to_peak(hl)
		assert_true(p >= prev, "level must not drop as HL rises (hl %d)" % hl)
		prev = p


func test_clamp_sample() -> void:
	assert_near(AudioSafety.clamp_sample(1.0), AudioSafety.peak_ceiling(), 1e-6)
	assert_near(AudioSafety.clamp_sample(-1.0), -AudioSafety.peak_ceiling(), 1e-6)


func test_bus_limiters_are_installed() -> void:
	var tones := AudioServer.get_bus_index(AudioSafety.TONES_BUS)
	assert_true(tones > 0, "Tones bus exists")
	var found := false
	for i in AudioServer.get_bus_effect_count(tones):
		var fx := AudioServer.get_bus_effect(tones, i)
		if fx is AudioEffectHardLimiter:
			found = true
			assert_true((fx as AudioEffectHardLimiter).ceiling_db <= -12.0, "Tones limiter ceiling")
	assert_true(found, "Tones bus has a hard limiter")
	var master_ok := false
	for i in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			master_ok = true
	assert_true(master_ok, "Master bus has a hard limiter")


func test_sfx_are_quiet() -> void:
	var sfx := autoload("Sfx")
	for s: StringName in sfx.get("SOUNDS"):
		var wav: AudioStreamWAV = sfx.call("get_stream", s)
		assert_true(wav != null, "sound %s generates" % s)
		var peak := 0
		var data := wav.data
		for i in range(0, data.size(), 2):
			peak = maxi(peak, absi(data.decode_s16(i)))
		assert_true(peak / 32767.0 <= db_to_linear(AudioSafety.SFX_PEAK_DBFS) + 0.001, "sfx %s peak" % s)


func test_tone_generator_respects_mapping() -> void:
	var gen := ToneGenerator.new()
	add_node(gen)
	gen.start_tone("right", 1000, 120)
	assert_true(gen.current_peak() <= AudioSafety.peak_ceiling() + 1e-6)
	gen.stop_tone()

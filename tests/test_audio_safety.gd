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


## v3: the narrow-band masker is quieter than a tone at the same dial number and never above its own ceiling.
func test_masker_mapping_is_capped_and_quiet() -> void:
	var cap := AudioSafety.masker_ceiling()
	assert_near(linear_to_db(cap), AudioSafety.MASKER_CEILING_DBFS, 0.01)
	assert_true(AudioSafety.MASKER_CEILING_DBFS < AudioSafety.PEAK_CEILING_DBFS, "masker ceiling below the tone ceiling")
	for db: int in [0, 25, 50, 80, 100, 140]:
		var rms := AudioSafety.masker_to_rms(db)
		assert_true(rms <= cap + 1e-6, "masker rms at %d dB EM capped" % db)
		assert_true(rms <= AudioSafety.hl_to_peak(db) / sqrt(2.0) + 1e-6, "masker no louder than a tone at %d" % db)
	assert_true(AudioSafety.masker_to_rms(30) > AudioSafety.masker_to_rms(20), "monotonic")
	assert_near(absf(AudioSafety.clamp_masker_sample(5.0)), cap, 1e-6)
	assert_near(absf(AudioSafety.clamp_masker_sample(-5.0)), cap, 1e-6)


## v3: the rendered masking noise: only in the masker's ear, never above its ceiling even at the
## top of the dial, about masker_to_rms() loud, and silent again after stop_masker().
func test_masker_render_is_safe() -> void:
	var gen := ToneGenerator.new()
	gen.start_masker("left", 1000, 100)
	var buf := gen.render(22050)
	var cap := AudioSafety.masker_ceiling()
	var sum := 0.0
	for i in buf.size():
		assert_true(absf(buf[i].x) <= cap + 1e-6, "left sample %d above the masker ceiling" % i)
		assert_eq(buf[i].y, 0.0, "nothing in the right ear")
		if i >= 11025:
			sum += buf[i].x * buf[i].x
		if absf(buf[i].x) > cap + 1e-6 or buf[i].y != 0.0:
			break
	gen.set_masker(1000, 40)
	buf = gen.render(22050)
	sum = 0.0
	for i in range(11025, buf.size()):
		sum += buf[i].x * buf[i].x
	var rms_db := linear_to_db(sqrt(sum / 11025.0))
	assert_near(rms_db, linear_to_db(AudioSafety.masker_to_rms(40)), 3.0, "masker level tracks the dial")
	# with a tone in the right ear at the same time, each stays in its own channel
	gen.start_tone("right", 1000, 40)
	buf = gen.render(4410)
	var right_peak := 0.0
	for i in buf.size():
		right_peak = maxf(right_peak, absf(buf[i].y))
	assert_true(right_peak > 0.0 and right_peak <= AudioSafety.peak_ceiling() + 1e-6, "tone right")
	gen.stop_tone()
	gen.stop_masker()
	gen.render(8820)
	buf = gen.render(2205)
	var tail := 0.0
	for i in buf.size():
		tail = maxf(tail, absf(buf[i].x))
	assert_eq(tail, 0.0, "silent after stop_masker")
	gen.free()

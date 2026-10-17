extends TestCase
## Builder A: the tone generator (core/tone_generator.gd). Safe level mapping, ear routing,
## click-free ramps, pulsed / warble stimuli. Uses render(), the pure DSP path.

const SR := ToneGenerator.MIX_RATE


func _gen() -> ToneGenerator:
	return ToneGenerator.new()  # not added to the tree: no audio server needed


func _rms_dbfs(buf: PackedVector2Array, channel_right: bool, from: int = 0) -> float:
	var sum := 0.0
	var n := 0
	for i in range(from, buf.size()):
		var v := buf[i].y if channel_right else buf[i].x
		sum += v * v
		n += 1
	return linear_to_db(sqrt(sum / maxf(1.0, n)))


func _peak(buf: PackedVector2Array) -> float:
	var p := 0.0
	for v: Vector2 in buf:
		p = maxf(p, maxf(absf(v.x), absf(v.y)))
	return p


func test_zero_hl_plays_near_minus_75_dbfs() -> void:
	var g := _gen()
	g.start_tone("right", 1000, 0)
	var buf := g.render(int(SR * 0.5))
	assert_near(_rms_dbfs(buf, true, int(SR * 0.1)), -75.0, 0.3, "0 dB HL RMS")
	g.free()


func test_mapping_is_0_6_db_per_db_hl() -> void:
	var g := _gen()
	g.start_tone("left", 1000, 50)
	var buf := g.render(int(SR * 0.4))
	assert_near(_rms_dbfs(buf, false, int(SR * 0.1)), -45.0, 0.3, "50 dB HL RMS")
	g.free()


func test_peak_never_above_minus_12_dbfs() -> void:
	var ceiling := db_to_linear(-12.0)
	for stim in [ToneGenerator.Stimulus.PURE, ToneGenerator.Stimulus.PULSED, ToneGenerator.Stimulus.WARBLE]:
		for hl: int in [90, 110, 120, 140]:
			var g := _gen()
			g.set_stimulus(stim)
			g.start_tone("right", 4000, hl)
			var buf := g.render(int(SR * 0.3))
			assert_true(_peak(buf) <= ceiling + 1e-6, "stim %d at %d dB HL peaks at %f dBFS" % [stim, hl, linear_to_db(_peak(buf))])
			g.free()


func test_right_ear_plays_only_right_channel() -> void:
	var g := _gen()
	g.start_tone("right", 1000, 60)
	var buf := g.render(int(SR * 0.2))
	var left_energy := 0.0
	var right_energy := 0.0
	for v: Vector2 in buf:
		left_energy += absf(v.x)
		right_energy += absf(v.y)
	assert_eq(left_energy, 0.0, "nothing in the left channel")
	assert_true(right_energy > 0.0, "tone in the right channel")
	g.free()


func test_left_ear_plays_only_left_channel() -> void:
	var g := _gen()
	g.start_tone("left", 2000, 60)
	var buf := g.render(int(SR * 0.2))
	var left_energy := 0.0
	var right_energy := 0.0
	for v: Vector2 in buf:
		left_energy += absf(v.x)
		right_energy += absf(v.y)
	assert_eq(right_energy, 0.0, "nothing in the right channel")
	assert_true(left_energy > 0.0, "tone in the left channel")
	g.free()


func test_ramps_are_click_free_and_silence_is_exact() -> void:
	var g := _gen()
	var amp := AudioSafety.hl_to_peak(80)
	g.start_tone("right", 1000, 80)
	var on := g.render(int(SR * 0.2))
	assert_true(absf(on[0].y) < amp * 0.01, "starts from silence")
	var max_step := TAU * 1000.0 / SR * amp * 1.05
	for i in range(1, on.size()):
		assert_true(absf(on[i].y - on[i - 1].y) <= max_step, "no jump at sample %d" % i)
		if absf(on[i].y - on[i - 1].y) > max_step:
			break
	g.stop_tone()
	var off := g.render(int(SR * 0.1))
	for i in range(1, off.size()):
		if absf(off[i].y - off[i - 1].y) > max_step:
			fail("click while stopping at sample %d" % i)
			break
	var tail := g.render(256)
	assert_eq(_peak(tail), 0.0, "exact silence after the ramp")
	assert_false(g.is_on())
	g.free()


func test_pulsed_tone_has_gaps() -> void:
	var g := _gen()
	g.set_stimulus(ToneGenerator.Stimulus.PULSED)
	g.start_tone("right", 1000, 60)
	var buf := g.render(int(SR * ToneGenerator.PULSE_PERIOD_S * 2))
	var quiet := 0
	for i in range(int(SR * 0.05), buf.size()):
		if absf(buf[i].y) < 1e-9:
			quiet += 1
	assert_between(quiet / float(buf.size()), 0.35, 0.55, "about half of each pulse cycle is silent")
	g.free()


func test_warble_modulates_frequency() -> void:
	var g := _gen()
	g.set_stimulus(ToneGenerator.Stimulus.WARBLE)
	g.start_tone("left", 1000, 60)
	var buf := g.render(int(SR * 0.2))
	# Count zero crossings in two quarter-cycles of the 5 Hz LFO: rising vs falling frequency.
	var seg := int(SR * 0.05)
	var a := _crossings(buf, 0, seg)
	var b := _crossings(buf, int(SR * 0.1), seg)
	assert_true(a > b + 3, "frequency swings up then down (%d vs %d crossings)" % [a, b])
	g.free()


func _crossings(buf: PackedVector2Array, from: int, n: int) -> int:
	var c := 0
	for i in range(from + 1, from + n):
		if (buf[i - 1].x < 0.0) != (buf[i].x < 0.0):
			c += 1
	return c


func test_generator_runs_in_tree() -> void:
	var g := ToneGenerator.new()
	add_node(g)
	g.start_tone("right", 1000, 40)
	await wait_frames(3)
	assert_true(g.is_on())
	assert_true(g.current_peak() <= AudioSafety.peak_ceiling())
	g.stop_tone()
	await wait_frames(2)

# core: integration notes

## Speech (Day 3 onwards)

`core/speech/` is new (CONTRACTS.md §9). Shared-file changes are additive: `PatientProfile.speech` and
`speech_value()`, the speech signals in `autoload/events.gd`, the speech constants in
`autoload/audio_safety.gd`, the `familiarize` / `speech` phases and the `mike` chapter in `autoload/game.gd`.

## Change request: the headless exit hang (`core/tone_generator.gd`) (done)

**Done** at the merge of main into the Day 2 feedback branch: `ToneGenerator` now keeps the streams of
freed generators in the same small static list (`_retired`, last 16, filled on `NOTIFICATION_PREDELETE`).
Nothing else changed: Day 1 and Day 2 tones and the masker sound and route exactly as before.

The "summary printed, then timeout" hang in `world/INTEGRATION_NOTES.md` has a cause, found with gdb on a
hung run:

- An `AudioStreamGeneratorPlayback` points at its `AudioStreamGenerator` without holding a reference.
- When an `AudioStreamPlayer` is freed while it plays a generator, its stream is freed with it, but the
  audio thread mixes the playback once more for its fade-out. That mix reads the generator's mix rate
  from freed memory.
- With unlucky garbage the resampler's step comes out negative, and its refill loop then runs for
  practically ever while holding the AudioServer lock. The main thread later waits forever in
  `pthread_join` at quit, or in `pthread_mutex_lock` mid-run (the old `add_bus_effect` hang).

`SpeechVoice` now keeps the streams of freed voices in a small static list (`_retired`, last 16), so that
last mix reads a live object. A test that freed a voice during masking noise used to hang the suite on
every run; with the fix, three full runs in a row exited 0.

`ToneGenerator` (Day 1 and 2) has the same pattern and is the likely source of the old 1-in-4-to-10 hang.
The same few lines would fix it (not changed here, it belongs to the chapter 1 code):

```gdscript
const RETIRED_KEEP := 16
static var _retired: Array[AudioStream] = []

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _player != null and _player.stream != null:
		_retired.append(_player.stream)
		while _retired.size() > RETIRED_KEEP:
			_retired.pop_front()
```

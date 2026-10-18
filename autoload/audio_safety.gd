class_name AudioSafety
extends RefCounted
## AudioSafety: the ONLY place that maps simulated dB HL to playback level.
##
## Consumer headphones are uncalibrated, so every "dB HL" in the game is simulated.
## Rules (design notes §6, engine-and-fun §1.6):
##  - 0 dB HL plays at about -75 dBFS RMS; each dB HL adds 0.6 dB.
##  - Peak sample amplitude never exceeds -12 dBFS, whatever the displayed level.
##  - The "Tones" bus carries a hard limiter at -12 dBFS and Master one at -6 dBFS
##    (res://default_bus_layout.tres), as a second and third line of defence.
##  - "Too loud" gags are visual. Never play a loud sound to make a joke.
## Any tone generator MUST call hl_to_peak() (or hl_to_dbfs()) and nothing else; any masking-noise
## generator MUST call masker_to_rms() and clamp_masker_sample() (v3).

const DBFS_AT_0_HL := -75.0
const DBFS_PER_DB_HL := 0.6
const FLOOR_DBFS := -90.0
## Hard ceiling for any synthesized sample (peak, dBFS).
const PEAK_CEILING_DBFS := -12.0
## Bus limiter ceilings written into default_bus_layout.tres by tools/build_assets.gd.
const TONES_BUS_CEILING_DB := -12.0
const MASTER_BUS_CEILING_DB := -6.0
## UI sound effects are normalised to this peak (quiet and friendly).
const SFX_PEAK_DBFS := -18.0

## (v3) Narrow-band masking noise: plays this much quieter than a tone at the same dial number,
## and its samples never exceed MASKER_CEILING_DBFS (a hiss, never a blast).
const MASKER_OFFSET_DB := -6.0
const MASKER_CEILING_DBFS := -24.0

## (Speech, CONTRACTS.md §9) Words (the murmur or a recording) play with their RMS this far below
## a tone at the same dial number, so their peaks (about 12 dB above the RMS) land near the tone's;
## the RMS never exceeds SPEECH_CEILING_DBFS and every sample still goes through clamp_sample().
## Speech noise and party babble use the masker mapping (masker_to_rms, clamp_masker_sample).
const SPEECH_OFFSET_DB := -9.0
const SPEECH_CEILING_DBFS := -27.0

const TONES_BUS := &"Tones"
const SFX_BUS := &"Sfx"
const MUSIC_BUS := &"Music"
const VOICE_BUS := &"Voice"


## Simulated dB HL -> RMS dBFS of a sine, before the peak ceiling.
static func hl_to_dbfs(hl: float) -> float:
	var rms := clampf(DBFS_AT_0_HL + DBFS_PER_DB_HL * hl, FLOOR_DBFS, PEAK_CEILING_DBFS)
	return rms


## Simulated dB HL -> peak amplitude (0..1) for a sine tone. Always <= PEAK_CEILING_DBFS.
static func hl_to_peak(hl: float) -> float:
	var peak := pow(10.0, hl_to_dbfs(hl) / 20.0) * sqrt(2.0)
	return minf(peak, peak_ceiling())


static func peak_ceiling() -> float:
	return pow(10.0, PEAK_CEILING_DBFS / 20.0)


## Clamp any sample to the safety ceiling (use as the last step of every generator).
static func clamp_sample(v: float) -> float:
	var c := peak_ceiling()
	return clampf(v, -c, c)


## (v3) Masker dial level (dB EM, simulated) -> target RMS amplitude (0..1) of the noise.
## Generators must still clamp every sample with clamp_masker_sample().
static func masker_to_rms(db_em: float) -> float:
	var rms_db := clampf(DBFS_AT_0_HL + DBFS_PER_DB_HL * db_em + MASKER_OFFSET_DB, FLOOR_DBFS, MASKER_CEILING_DBFS)
	return pow(10.0, rms_db / 20.0)


static func masker_ceiling() -> float:
	return pow(10.0, MASKER_CEILING_DBFS / 20.0)


## Clamp a masker sample to its own (lower) ceiling, then to the global one.
static func clamp_masker_sample(v: float) -> float:
	var c := masker_ceiling()
	return clamp_sample(clampf(v, -c, c))


## (Speech) Simulated speech level (dB HL) -> target RMS amplitude (0..1) of a word.
## Generators must still clamp every sample with clamp_sample().
static func speech_to_rms(hl: float) -> float:
	var rms_db := clampf(DBFS_AT_0_HL + DBFS_PER_DB_HL * hl + SPEECH_OFFSET_DB, FLOOR_DBFS, SPEECH_CEILING_DBFS)
	return pow(10.0, rms_db / 20.0)


static func speech_ceiling() -> float:
	return pow(10.0, SPEECH_CEILING_DBFS / 20.0)

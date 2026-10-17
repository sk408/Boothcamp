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
## Any tone or noise generator MUST call hl_to_peak() (or hl_to_dbfs()) and nothing else.

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

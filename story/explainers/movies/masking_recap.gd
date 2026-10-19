extends RefCounted
## Hoot's masking movie, the short version (v4 polish): one "card" scene (data only, no stage code)
## that plays when Day 2's masking phase opens, about 8 minutes after the full movie, so the plateau
## steps are fresh when the player needs them. A "short" (recap): never listed for replay; Esc or
## "Skip movie" skips it like any movie. Facts as in masking.gd: noise in the non-test ear, start at
## that ear's air threshold + 10 (plus the occlusion allowance for low-pitch bone), 5 dB steps, a
## plateau = the same answer through 15 dB more noise.

const MOVIE: Dictionary = {
	"id": "masking_recap",
	"title": "Hoot's masking movie",
	"subtitle": "The short version",
	"chapter": "bonnie",
	"narrator": "Hoot",
	"short": true,
	"scenes": [
		{
			"id": "recap", "set": "card", "title": "Masking, the short version", "duration": 12.0,
			"captions": ["Short version: shhh in the other ear, up 5 at a time, until the answer stays flat."],
			"teaches": "The masking routine in four steps: noise in the non-test ear, start level, 5 dB steps, plateau.",
			"board": "A cream title card pops in; four starred lines appear one by one; the shhh cloud bobs beside them; a little Hoot waves bottom-left.",
			"params": {"heading": "Masking, the short version", "icon": "cloud", "tint": "#f3ecff",
				"lines": ["Shhh goes in the OTHER ear", "Start: its air + 10 (+ occlusion)", "Heard? Shhh up 5. Missed? Beep up 5", "Flat for 15 dB of shhh = the truth"],
				"line_at": [0.8, 2.6, 4.4, 6.2]},
			"cues": [{"t": 0.2, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 6.2, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
	],
}

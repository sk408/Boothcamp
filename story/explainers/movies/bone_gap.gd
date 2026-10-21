extends RefCounted
## Two roads to the cochlea (clinical review D2-7): a two-card short that plays on Day 2 after the
## air results, before bone and the gap are used and quizzed. Air takes the canal, the middle ear and
## the cochlea; bone buzzes the skull and mostly skips the middle ear. The gap is air minus bone; the
## gap and the bone line give the type (StatPearls, Audiogram Interpretation; ASHA, Type, Degree and
## Configuration of Hearing Loss). A "short": never listed for replay; Esc or "Skip movie" skips it.

const MOVIE: Dictionary = {
	"id": "bone_gap",
	"title": "Two roads to the cochlea",
	"subtitle": "Air, bone and the gap",
	"chapter": "bonnie",
	"narrator": "Hoot",
	"short": true,
	"scenes": [
		{
			"id": "roads", "set": "card", "title": "Two roads to the cochlea", "duration": 10.0,
			"captions": ["Two roads to the cochlea: air takes the long way, bone takes the shortcut."],
			"teaches": "Air conduction goes through the canal and the middle ear to the cochlea; bone conduction vibrates the skull and mostly skips the middle ear.",
			"board": "A cream card pops in; three lines appear one by one; Righty and Lefty wave beside them; a little Hoot waves bottom-left.",
			"params": {"heading": "Two roads to the cochlea", "icon": "snails", "tint": "#e9f6ef",
				"lines": ["AIR: canal, middle ear, cochlea", "BONE: a buzz through the skull", "Bone mostly skips the middle ear"],
				"line_at": [0.8, 2.8, 4.8]},
			"cues": [{"t": 0.2, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}],
		},
		{
			"id": "gap", "set": "card", "title": "Read the gap", "duration": 10.0,
			"captions": ["Air minus bone is the gap. The gap and the bone line tell you the type."],
			"teaches": "The air-bone gap and the three types: a big gap with normal bone is conductive; no gap with both down is sensorineural; a gap with bone down too is mixed.",
			"board": "A second card: four lines, the three types in capitals; a little Hoot waves bottom-left.",
			"params": {"heading": "Read the gap", "tint": "#fff4dc",
				"lines": ["The gap = air minus bone", "Big gap, bone normal: CONDUCTIVE", "No gap, both down: SENSORINEURAL", "Gap AND bone down: MIXED"],
				"line_at": [0.8, 2.6, 4.4, 6.2]},
			"cues": [{"t": 0.2, "sfx": "pop", "pitch": 1.2, "vol_db": -10.0}, {"t": 6.2, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
	],
}

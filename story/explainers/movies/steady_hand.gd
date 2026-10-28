extends RefCounted
## Hoot's Safe Support movie, "The Steady Hand" (docs/training/PRACTICAL_EXAM.md §3.2). The lead-in of The
## Practical's Station 2 (the Training room); replay from the title's "Hoot's Movies" (labelled
## "Training"; "training": true: never a day's own movie) or the station's card. DATA ONLY: the scenes
## are drawn by the station's sets script, story/training/practical/practical_sets.gd (sh_open, sh_grip,
## sh_grips) and the stage's "card".
## Facts (Steve reviews; CA_PRACTICAL_EXAM.md §3.3, the board's Safe Support sheet): anything in or near
## the ear (otoscope, ear light, syringe or gun) is held with Safe Support: one hand is the bridge on the
## head, the other holds the instrument braced on it, so the instrument moves WITH the head and not
## into the ear. An examiner stops a task done unsafely. The sneeze is a cartoon: no injury is shown.

const MOVIE: Dictionary = {
	"id": "steady_hand",
	"title": "Hoot's Safe Support movie",
	"subtitle": "The Steady Hand",
	"chapter": "gus",
	"narrator": "Hoot",
	"stage": "res://story/training/practical/practical_sets.gd",
	"seen_at": "sneeze",
	"training": true,
	"scenes": [
		{
			"id": "open", "set": "sh_open", "title": "Today's mystery", "duration": 9.0,
			"captions": ["Hoot's Movie Matinee! Today: The Steady Hand.",
				"What happens when your subject sneezes with a light in their ear?"],
			"caption_at": [0.3, 4.0],
			"teaches": "What the movie answers: how to hold a tool in the ear so a sudden move can't hurt.",
			"board": "A marquee card HOOT'S MOVIE MATINEE / The Steady Hand holds 7 s with two question chips, then a head in profile with a wobbly otoscope held like a pencil.",
			"params": {"card_hold": 7.0, "questions": ["They sneeze. Where does the light go?", "How do you hold it?"]},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 1.6, "sfx": "pop", "vol_db": -10.0}, {"t": 4.0, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}],
		},
		{
			"id": "wobble", "set": "sh_grip", "title": "The wobbly way", "duration": 10.0,
			"captions": ["Here's a light held like a pencil. Nothing touches the head.",
				"ACHOO! The head moves. The light doesn't. Ouch!"],
			"caption_at": [0.3, 4.6],
			"teaches": "An unbraced tool stays put when the head moves, so the tip goes deeper into the ear.",
			"board": "The otoscope held at its far end, shaking. At 4.6 s the head sneezes toward it: a red OW! burst at the ear; the chip 'Nothing touches the head'.",
			"params": {"tool": "oto_up", "grip": "pencil", "sneeze_at": 4.6, "chip": "Nothing touches the head", "chip_at": 1.5, "chip_color": "red"},
			"cues": [{"t": 4.8, "sfx": "boing", "pitch": 0.8, "vol_db": -12.0}],
		},
		{
			"id": "bridge", "set": "sh_grip", "title": "The bridge hand", "duration": 10.0,
			"captions": ["First, the bridge hand: on the head, above and behind the ear.",
				"Its thumb lifts the ear a little and steadies the head."],
			"caption_at": [0.3, 5.0],
			"teaches": "Safe Support step 1: one hand is the bridge, resting on the head and lifting the outer ear.",
			"board": "The head alone; at 1.5 s the bridge hand slides onto the head above and behind the ear, its thumb on the top of the ear. Chip 'Bridge hand on the head'.",
			"params": {"tool": "oto_up", "grip": "safe", "bridge_at": 1.5, "tool_at": 99.0, "chip": "Bridge hand on the head", "chip_at": 2.0, "chip_color": "green"},
			"cues": [{"t": 1.5, "sfx": "pop", "vol_db": -10.0}],
		},
		{
			"id": "brace", "set": "sh_grip", "title": "Brace the light", "duration": 10.0,
			"captions": ["Then the light hand rests a finger on the bridge hand.",
				"Hands, head and light: one unit. Now go in, gently."],
			"caption_at": [0.3, 5.0],
			"teaches": "Safe Support step 2: the instrument hand is braced on the bridge hand, so all three move together.",
			"board": "The bridge hand is on; at 1.5 s the otoscope arrives with its hand, one finger reaching to the bridge hand: a green dot where they touch. Chip 'One unit'.",
			"params": {"tool": "oto_up", "grip": "safe", "tool_at": 1.5, "chip": "Hands, head and light: one unit", "chip_at": 5.0, "chip_color": "green"},
			"cues": [{"t": 1.5, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 5.0, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "sneeze", "set": "sh_grip", "title": "ACHOO!", "duration": 10.0,
			"captions": ["ACHOO! The head moves, and everything moves with it.",
				"The tip never goes deeper. If they sneeze, you ride along."],
			"caption_at": [0.3, 5.0],
			"teaches": "Braced, a sudden move carries the tool with the head: it never goes deeper.",
			"board": "The braced grip sneezes every 2.6 s from 0.6 s: head, hands and light jolt together, no OW. Chip 'Moved with the head'.",
			"params": {"tool": "oto_up", "grip": "safe", "sneeze_at": 0.6, "chip": "Moved with the head", "chip_at": 1.4, "chip_color": "green"},
			"cues": [{"t": 0.8, "sfx": "whoosh", "vol_db": -14.0}, {"t": 3.4, "sfx": "whoosh", "vol_db": -14.0}],
		},
		{
			"id": "float", "set": "sh_grip", "title": "Half a grip", "duration": 9.0,
			"captions": ["A bridge hand alone isn't enough. This light hand floats.",
				"ACHOO! The head moves, the light stays. Brace it!"],
			"caption_at": [0.3, 4.6],
			"teaches": "Both hands matter: a bridge hand with a floating instrument hand still lets the tip go in.",
			"board": "The bridge hand is on, the otoscope hand floats with red wobble marks between the finger and the bridge hand; at 4.6 s a sneeze: OW!",
			"params": {"tool": "oto_down", "grip": "float", "sneeze_at": 4.6, "chip": "Floating hand: brace it", "chip_at": 1.5, "chip_color": "red"},
			"cues": [{"t": 4.8, "sfx": "boing", "pitch": 0.8, "vol_db": -12.0}],
		},
		{
			"id": "grips", "set": "sh_grips", "title": "Every tool", "duration": 11.0,
			"captions": ["The same rule for every tool near the ear:",
				"the otoscope, handle up or down, the ear light, the impression syringe."],
			"caption_at": [0.3, 3.0],
			"teaches": "Safe Support covers the otoscope (handle up or down), the ear light and the syringe or gun.",
			"board": "Four panels pop in every 2 s: otoscope handle up, handle down, ear light, syringe, each braced on a bridge hand; from 8.5 s all four sneeze and ride along.",
			"params": {"pop_at": 0.4, "sneeze_at": 8.5},
			"cues": [{"t": 0.4, "sfx": "pop", "vol_db": -12.0}, {"t": 2.4, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 4.4, "sfx": "pop", "pitch": 1.2, "vol_db": -12.0}, {"t": 6.4, "sfx": "pop", "pitch": 1.3, "vol_db": -12.0}],
		},
		{
			"id": "stop", "set": "card", "title": "Exam day", "duration": 8.0,
			"captions": ["In the exam, an unsafe move gets you stopped.", "That task is over. Brace first, every time."],
			"caption_at": [0.3, 4.0],
			"teaches": "On the California practical an examiner stops a task done unsafely; it may not be finished.",
			"board": "A red title card STOP: UNSAFE with two lines popping in, Hoot pointing.",
			"params": {"heading": "STOP: unsafe", "lines": ["An examiner stops the task", "It may not be finished", "Brace first, every time"], "tint": "#ffb3a7", "icon": "hoot"},
			"cues": [{"t": 0.6, "sfx": "thunk", "pitch": 0.9, "vol_db": -12.0}],
		},
		{
			"id": "wrap", "set": "card", "title": "The Safe Support card", "duration": 9.0,
			"captions": ["Hands, head and light: one unit.", "Now earn your Safe Support card. Steady hands!"],
			"caption_at": [0.3, 4.0],
			"teaches": "The rule to remember: bridge hand on the head, the instrument hand braced on it.",
			"board": "The Safe Support card's lines as a title card, line by line.",
			"params": {"heading": "Safe Support", "lines": ["Bridge hand on the head", "Instrument hand braced on it", "Hands, head, light: one unit", "They sneeze? You ride along"], "tint": "#bdf0d8", "icon": "hoot"},
			"cues": [{"t": 0.4, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
	],
}

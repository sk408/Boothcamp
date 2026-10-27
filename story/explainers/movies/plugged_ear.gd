extends RefCounted
## Hoot's occlusion movie, "The Plugged Ear" (docs/training/MASKING_TRAINER.md §3.5). The lead-in of
## Masking School's Station 5 (the Training room); replay from the title's "Hoot's Movies" (labelled
## "Training"; "training": true: never a day's own movie) or the station's card. DATA ONLY: the scenes are drawn by the station's sets
## script, story/training/masking/school_sets.gd (pe_open, pe_ear, pe_masker) and the stage's "card".
## Facts (Steve reviews): covering a NORMAL ear makes low-pitch bone-conducted sound louder in it (the
## occlusion effect): the sound the bone sets going in the canal can't escape. The game's allowance
## (ClinicRules.OCCLUSION_DB): headphones 250 +15, 500 +15, 750 +10, 1k +10, 2k and up 0; deep inserts
## 0 (teaching default; shallow ones leave some). An ear with its own conductive loss gets none. It
## matters for masking because the masker covers the other ear during bone tests. Nothing is played to
## test the player: the "fingers in your ears" line is something they have already felt.

const MOVIE: Dictionary = {
	"id": "plugged_ear",
	"title": "Hoot's occlusion movie",
	"subtitle": "The Plugged Ear",
	"chapter": "bonnie",
	"narrator": "Hoot",
	"stage": "res://story/training/masking/school_sets.gd",
	"seen_at": "masker",
	"training": true,
	"scenes": [
		{
			"id": "open", "set": "pe_open", "title": "Today's mystery", "duration": 12.0,
			"captions": ["Hoot's Movie Matinee! Today: why does a covered ear hear bone LOUDER?",
				"And how much do we add for it? Let's plug an ear.",
				"Hum with your ears open: the low hum leaks out of the canal."],
			"caption_at": [0.3, 4.0, 7.6],
			"teaches": "What the movie answers: why covering an ear boosts bone sound in it, and the add-on for masking.",
			"board": "A marquee card HOOT'S MOVIE MATINEE / The Plugged Ear holds 7 s with two question chips. Then a cut-away ear: skull bone, the canal, the drum, a red snail cochlea, a humming box on the bone. Purple wave arcs run out of the open canal and fade: 'leaks out'.",
			"params": {"card_hold": 7.0, "questions": ["Why does a covered ear hear bone LOUDER?", "How much do we add?"]},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 1.6, "sfx": "pop", "vol_db": -10.0}, {"t": 4.0, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}],
		},
		{
			"id": "plug", "set": "pe_ear", "title": "Plug it", "duration": 10.0,
			"captions": ["Now cover the ear. The low hum can't escape: it bounces back in.",
				"Covering a NORMAL ear makes LOW bone tones LOUDER in it."],
			"caption_at": [0.3, 5.0],
			"teaches": "The occlusion effect: covering a normal ear makes low-pitch bone-conducted sound louder in it.",
			"board": "The same ear. At 2 s a red headphone slides over the outer ear; the waves turn back off it (orange) and pile up at the drum. The cochlea snail's eyes go wide; the LOUDER meter jumps to +15.",
			"params": {"cover": "phones", "freq": 250, "cover_at": 2.0},
			"cues": [{"t": 2.0, "sfx": "thunk", "pitch": 0.9, "vol_db": -12.0}, {"t": 3.0, "sfx": "boing", "pitch": 0.8, "vol_db": -14.0}],
		},
		{
			"id": "lows", "set": "pe_ear", "title": "Only the lows", "duration": 13.0,
			"captions": ["Low pitches make slow, big waves that fill the canal. They boom the most.",
				"250 and 500: plus 15. 750 and 1k: plus 10.",
				"2k and up: quick little waves don't care. Nothing."],
			"caption_at": [0.3, 4.6, 9.0],
			"teaches": "The boost is biggest at the lowest pitches (+15 at 250 and 500, +10 at 750 and 1k) and none from 2 kHz up.",
			"board": "The covered ear sweeps 250, 500, 750, 1k, 2k, 4k, two seconds each; the waves shrink and quicken. A bar chart on the right grows a bar per pitch: +15, +15, +10, +10, 0, 0.",
			"params": {"cover": "phones", "sweep": true},
			"cues": [{"t": 0.7, "sfx": "pop", "pitch": 0.8, "vol_db": -12.0}, {"t": 2.7, "sfx": "pop", "pitch": 0.9, "vol_db": -12.0}, {"t": 4.7, "sfx": "pop", "pitch": 1.0, "vol_db": -12.0}, {"t": 6.7, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 8.7, "sfx": "pop", "pitch": 1.2, "vol_db": -12.0}, {"t": 10.7, "sfx": "pop", "pitch": 1.3, "vol_db": -12.0}],
		},
		{
			"id": "masker", "set": "pe_masker", "title": "Why the masker cares", "duration": 11.0,
			"captions": ["Masking puts an earphone on the OTHER ear. Now that ear booms.",
				"It hears the bone tone better, so the shhh needs more: the occlusion add-on."],
			"caption_at": [0.3, 5.0],
			"teaches": "During masked bone tests the masker covers the non-test ear, so its occlusion boost is added to the start level.",
			"board": "The big head: the bone buzzer on Righty, a blue headphone pops onto Lefty, who jolts: BOOM +15. The shhh cloud grows bigger; a chip: 'shhh: air + 10 + 15'.",
			"params": {},
			"cues": [{"t": 1.0, "sfx": "pop", "vol_db": -10.0}, {"t": 3.0, "sfx": "boing", "pitch": 0.8, "vol_db": -12.0}, {"t": 5.4, "sfx": "whoosh", "vol_db": -14.0}],
		},
		{
			"id": "insert", "set": "pe_ear", "title": "Deep inserts", "duration": 9.0,
			"captions": ["A deep foam insert leaves almost no air to boom.", "This game counts it as zero. Shallow ones leave a little."],
			"caption_at": [0.3, 4.6],
			"teaches": "A deeply placed insert earphone nearly cancels the occlusion effect (the game uses 0).",
			"board": "The ear again at 250: a yellow foam insert slides deep into the canal at 1.5 s; only a sliver of air is left, the waves are short, the meter stays at +0.",
			"params": {"cover": "insert", "freq": 250, "cover_at": 1.5},
			"cues": [{"t": 1.5, "sfx": "pop", "pitch": 0.9, "vol_db": -10.0}],
		},
		{
			"id": "blocked", "set": "pe_ear", "title": "A blocked ear", "duration": 9.0,
			"captions": ["An ear with its own conductive loss already hears through a plug.", "No extra boom: nothing to add."],
			"caption_at": [0.3, 5.0],
			"teaches": "An ear with its own conductive loss shows no extra occlusion effect, so no add-on.",
			"board": "The ear's middle ear is filled with blue fluid; a headphone goes on at 1.5 s, but the meter stays at +0; chip 'own conductive loss: already plugged'.",
			"params": {"cover": "blocked", "freq": 250, "cover_at": 1.5},
			"cues": [{"t": 1.5, "sfx": "thunk", "pitch": 0.9, "vol_db": -12.0}],
		},
		{
			"id": "felt", "set": "card", "title": "You've felt it", "duration": 9.0,
			"captions": ["You've felt it: plug your ears and talk. Your own voice booms.",
				"A sealed hearing aid does it too: Gus sounded like he was in a barrel."],
			"caption_at": [0.3, 4.6],
			"teaches": "Everyday occlusion: fingers in the ears while talking, or a sealed hearing aid (Gus, Day 14).",
			"board": "A title card with three starred lines popping in, Hoot cheering.",
			"params": {"heading": "You've felt it!", "lines": ["Fingers in ears: your voice booms", "Sealed aid: 'in a barrel'", "Gus felt it on Day 14"], "icon": "hoot"},
			"cues": [{"t": 1.0, "sfx": "pop", "vol_db": -12.0}],
		},
		{
			"id": "wrap", "set": "card", "title": "The pocket card", "duration": 10.0,
			"captions": ["Lows, covered, normal ear, bone only: add it.", "Now earn your Pocket Card. Fill it from memory!"],
			"caption_at": [0.3, 5.0],
			"teaches": "The rule to remember: low pitches, a covered normal ear, bone tests only.",
			"board": "The pocket card's numbers as a title card, line by line.",
			"params": {"heading": "The Pocket Card", "lines": ["250 +15   500 +15", "750 +10   1k +10", "2k and up: 0. Inserts: 0.", "Bone only. Covered NORMAL ear."], "tint": "#ffd9a6", "icon": "hoot"},
			"cues": [{"t": 0.4, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
	],
}

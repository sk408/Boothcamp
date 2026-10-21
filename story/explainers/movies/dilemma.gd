extends RefCounted
## Hoot's dilemma movie, "The Masking Dilemma" (docs/CASES.md section 10, question 26). Plays on Day 13
## when the masking dilemma first shows, right after Hoot's on_dilemma lines and before he lends his
## inserts (story/level_case.gd DAY_MOVIES: always its lead-in while unwatched); replay from Day 13's
## pause menu or the title. DATA ONLY: the scenes are drawn by story/case_movies/dilemma_sets.gd.
## Facts (Steve reviews), the game's own rules (autoload/clinic_rules.gd) on Bev's numbers at 1 kHz
## (core/patients/bev.tres: air 55, bone 10, both ears) and 2 kHz (air 45, bone 25): masking noise
## starts at the non-test ear's air + 10 (no occlusion allowance: that ear's middle ear is blocked);
## the noise crosses back to the test cochlea minus the interaural attenuation (rule IA: headphones
## 40, inserts 55); it hushes the test ear once noise - IA reaches the test ear's bone. 1 kHz with
## headphones: at least 65 to mask, hushing from 50: no room (the dilemma). Inserts: hushing from 65,
## still no room at 500 and 1k. 2 kHz: 55 to mask, hushing from 65 with headphones (one 5 dB step),
## from 80 with inserts: safe up to 75, room for a plateau (15 dB, three steps). No room = the purple
## ? (plateau not reached): the test's limit, not the ear's. Every number it shows is checked against
## ClinicRules in story/tests/test_cases.gd. Visual only: nothing loud ever plays.

const MOVIE: Dictionary = {
	"id": "dilemma",
	"title": "Hoot's dilemma movie",
	"subtitle": "The Masking Dilemma",
	"chapter": "bev",
	"narrator": "Hoot",
	"stage": "res://story/case_movies/dilemma_sets.gd",
	"seen_at": "question",
	"scenes": [
		{
			"id": "open", "set": "dl_open", "title": "Today's mystery", "duration": 11.0,
			"captions": ["Today's mystery: what if BOTH ears are blocked? Can masking still work?",
				"It's called the masking dilemma. Let's squeeze into the skull and see."],
			"caption_at": [0.3, 5.0],
			"teaches": "What the movie answers: masking when both ears have a conductive loss runs out of room (the masking dilemma).",
			"board": "Curtains open on a marquee card HOOT'S DILEMMA MOVIE / The Masking Dilemma, two corks beside the title; it holds 8 s with two question chips. Then the big head pops in with Righty and Lefty, a cork stuck in each ear canal; Hoot waves.",
			"params": {"card_hold": 8.0, "questions": ["Why must the shhh be LOUD?", "How can inserts make room?"]},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 2.0, "sfx": "pop", "vol_db": -10.0}, {"t": 4.6, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 8.6, "sfx": "pop", "pitch": 0.9, "vol_db": -10.0}, {"t": 9.0, "sfx": "pop", "pitch": 1.0, "vol_db": -10.0}],
		},
		{
			"id": "corks", "set": "dl_corks", "title": "Two stubborn corks", "duration": 12.0,
			"captions": ["Bev's middle ears are both stiff, like corks. Sound from outside must be LOUD to get through.",
				"Her cochleas are fine: bone shows 10 dB at 1k. Her air needs 55."],
			"caption_at": [0.3, 6.2],
			"teaches": "A conductive loss in both ears: air needs 55 dB to get past the stiff middle ears, while bone (straight to the cochleas) shows 10.",
			"board": "The head with a cork in each canal. A red cup sends a soft 30 dB note: it bonks off the right cork. A 55 dB note squeezes through and Righty perks up: AIR 55. Then the cup pops off, the bone buzzer clicks on behind the right ear, both snails buzz (bone skips the corks): BONE 10.",
			"params": {"air": 55, "bone": 10, "soft": 30},
			"cues": [{"t": 1.4, "sfx": "boing", "pitch": 1.2, "vol_db": -14.0}, {"t": 3.6, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 4.2, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}, {"t": 6.6, "sfx": "thunk", "pitch": 1.3, "vol_db": -10.0}, {"t": 7.4, "sfx": "squeak", "pitch": 0.6, "vol_db": -16.0}],
		},
		{
			"id": "loud", "set": "dl_loud", "title": "Shhh, loud enough", "duration": 12.0,
			"captions": ["To keep her left ear busy, the shhh must beat its cork: air 55, plus 10. That's 65!",
				"But 65 crosses the skull wall: minus 40 leaves 25. Righty hears from 10. Hushed!"],
			"caption_at": [0.3, 6.0],
			"teaches": "Masking noise must get past the non-test ear's blockage (its air + 10 = 65), and that much noise crosses back (65 - 40 = 25) above the test cochlea's 10: overmasking from the very first step.",
			"board": "The buzzer on the right, a blue cup on the left; the shhh cloud grows around Lefty as the noise dial climbs to 65; a chip '55 + 10 = 65'. The cloud spills through the wall under the toll sign AIR: -40, its tag counting 65 down to 25, and smothers Righty (who hears from 10): '25 is over 10: hushed!'. Hoot covers his eyes. Visual only.",
			"params": {"air": 55, "bone": 10, "ia": 40, "safety": 10},
			"cues": [{"t": 0.6, "sfx": "pop", "pitch": 0.9, "vol_db": -10.0}, {"t": 1.2, "sfx": "whoosh", "pitch": 0.6, "vol_db": -16.0}, {"t": 6.6, "sfx": "whoosh", "pitch": 0.5, "vol_db": -14.0}, {"t": 9.0, "sfx": "sad_trombone", "vol_db": -16.0}],
		},
		{
			"id": "window", "set": "dl_window", "title": "No room!", "duration": 13.0,
			"captions": ["Too little shhh and the Ghost answers. Too much and Righty is hushed. Masking lives between.",
				"With headphones: enough means 65, too much starts at 50. No room! The masking dilemma."],
			"caption_at": [0.3, 6.4],
			"teaches": "The masking window: from the least noise that masks (65) up to where the noise hushes the test ear (50). Here the window is upside down: no room at all.",
			"board": "A noise ruler from 40 to 90 dB. Row 1 (Lefty): yellow below 65 with a little Ghost (too little), mint from 65 (enough). Row 2 (Righty): mint below 50 (safe), coral from 50 (hushed). Row 3: where both are fine: nothing, and a NO ROOM! sign wobbles. HEADPHONES chip.",
			"params": {"enough": 65, "hushed": 50, "transducer": "HEADPHONES"},
			"cues": [{"t": 1.2, "sfx": "pop", "vol_db": -10.0}, {"t": 3.4, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 7.6, "sfx": "boing", "pitch": 0.7, "vol_db": -12.0}, {"t": 8.4, "sfx": "sad_trombone", "vol_db": -16.0}],
		},
		{
			"id": "inserts", "set": "dl_inserts", "title": "Inserts make room", "duration": 14.0,
			"captions": ["Insert earphones seal deep in the canal. The skull wall gets thicker: 55 dB, not 40.",
				"At 2k that opens room: shhh from 55 to 75, safely. Enough for a plateau!"],
			"caption_at": [0.3, 6.6],
			"teaches": "Insert earphones raise the interaural attenuation (rule: 55 dB, not 40), which can open a masking window: at 2 kHz, 55 to 75 dB, room for a 15 dB plateau.",
			"board": "The cups pop off; foam inserts squish, slide in and puff up deep in each canal. The wall grows a second layer of bricks and its sign flips to INSERTS: -55. Then the noise ruler at 2k: Lefty needs 55 (45 + 10); with headphones Righty is hushed from 65 (a sliver of room: one step), then the coral zone slides out to 80 with inserts and a mint window 55-75 opens with a brace: ROOM FOR A PLATEAU.",
			"params": {"ia_phones": 40, "ia_inserts": 55, "freq": 2000, "air": 45, "bone": 25},
			"cues": [{"t": 0.6, "sfx": "pop", "pitch": 1.2, "vol_db": -10.0}, {"t": 1.6, "sfx": "squeak", "pitch": 1.4, "vol_db": -16.0}, {"t": 3.6, "sfx": "thunk", "pitch": 0.9, "vol_db": -12.0}, {"t": 9.6, "sfx": "whoosh", "pitch": 1.2, "vol_db": -16.0}, {"t": 10.6, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}, {"t": 10.8, "sfx": "sparkle", "vol_db": -14.0}],
		},
		{
			"id": "question", "set": "dl_question", "title": "The purple ?", "duration": 11.0,
			"captions": ["At 500 and 1k it's still too tight, even with inserts. No plateau fits.",
				"So the chart gets a purple ?: the test's limit, not her ears'. The doctor knows why."],
			"caption_at": [0.3, 5.4],
			"teaches": "Where even inserts leave no room for a plateau, the masked bone gets a purple ? (plateau not reached): a limit of the test, not of the ear, which the referral explains.",
			"board": "Bev's audiogram: O and X at 55 / 55 / 45 / 35, bone brackets at 10 / 10 / 25 / 15. At 2k and 4k a mint tick (plateau: room with inserts); at 500 and 1k a purple ? pops beside each bracket. A chip: the test's limit, not her ears'.",
			"params": {"air": [55, 55, 45, 35], "bone": [10, 10, 25, 15], "room": [false, false, true, true]},
			"cues": [{"t": 1.4, "sfx": "ding", "pitch": 1.1, "vol_db": -12.0}, {"t": 1.8, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}, {"t": 3.6, "sfx": "pop", "pitch": 0.8, "vol_db": -10.0}, {"t": 4.0, "sfx": "pop", "pitch": 0.9, "vol_db": -10.0}],
		},
		{
			"id": "bow", "set": "dl_bow", "title": "That's a wrap", "duration": 6.0,
			"captions": ["Both ears blocked? Reach for inserts, and trust the ? when there's no room. Back to Bev!"],
			"teaches": "Recap: with both ears blocked, inserts can make room; where none is left, the ? tells the truth.",
			"board": "Righty and Lefty bow, foam inserts in hand; Hoot bows; the curtains close; THE END?; Back to our patient!",
			"params": {},
			"cues": [{"t": 0.4, "sfx": "fanfare", "pitch": 1.2, "vol_db": -16.0}],
		},
	],
}

extends RefCounted
## Hoot's masking movie, "The Cross-Hearing Ghost" (v4). Plays at the start of Day 2 before Bonnie
## arrives; replay from the pause menu. Storyboard and the facts behind it: docs/CHAPTER2.md §16.
## DATA ONLY: the player (explainer_player.gd) types "captions" (Hoot, typewriter, gibberish voice),
## fires "cues" (quiet Sfx stings, seconds from the scene start) and hands "set" + "params" to the
## stage (explainer_stage.gd), which animates the set over the scene's time. "board" is the
## animation brief for the stage builder (never shown). "teaches" is the one idea of the scene.
## Facts (Steve reviews): supra-aural (on-ear) IA at least 40 dB (the safe textbook minimum; real
## heads lose about 40-80, Bonnie's 60); inserts at least 55; bone IA 0-10 dB, treated as 0; plateau = the same answer through 15 dB
## more noise (three 5 dB steps); overmasking = noise minus IA reaches the test ear's cochlea.
## Every sound is quiet (Sfx, -18 dBFS peaks, played at -6 dB or softer); "too loud" and "too much
## noise" are shown, never played (CONTRACTS.md §1.3).

const MOVIE: Dictionary = {
	"id": "masking",
	"title": "Hoot's masking movie",
	"subtitle": "The Cross-Hearing Ghost",
	"chapter": "bonnie",
	"narrator": "Hoot",
	## Watching up to this scene counts as seen (Game.mark_movie_seen): a skip before it plays the movie again next visit.
	"seen_at": "plateau",
	"scenes": [
		{
			"id": "meet", "set": "meet", "title": "Meet the cochleas", "duration": 8.0,
			"captions": ["Hoot's Movie Matinee! Meet Righty and Lefty: two cochleas, one on each side of one head."],
			"teaches": "Each ear has its own cochlea, and both live in the same skull.",
			"board": "Curtains swish open on a cinema screen; title card HOOT'S MOVIE MATINEE / THE CROSS-HEARING GHOST (2 s). A big round cartoon head, seen from the front, with a see-through window. Two snail-shell cochleas pop in: red Righty on the screen's LEFT (her right is on your left), blue Lefty on the right, with name tags. They wave.",
			"params": {},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 2.6, "sfx": "pop", "pitch": 1.2, "vol_db": -8.0}, {"t": 3.0, "sfx": "pop", "pitch": 0.9, "vol_db": -8.0}],
		},
		{
			"id": "air", "set": "air", "title": "Air: one ear at a time", "duration": 8.0,
			"captions": ["An earphone sends a beep to ONE ear. Righty hears it. Lefty snoozes."],
			"teaches": "Air conduction: an earphone tests one ear at a time.",
			"board": "A red on-ear cup pops onto the head's right side. Little music-note beeps hop down the canal to Righty, who perks up and rings a tiny bell. Lefty sleeps: zzz bubbles.",
			"params": {"ear": "right"},
			"cues": [{"t": 0.4, "sfx": "pop", "vol_db": -8.0}, {"t": 1.6, "sfx": "note", "pitch": 1.0, "vol_db": -14.0}, {"t": 2.8, "sfx": "ding", "pitch": 1.3, "vol_db": -12.0}],
		},
		{
			"id": "wall", "set": "wall", "title": "The skull wall", "duration": 11.0,
			"captions": ["Crossing the skull costs at least 40 dB with on-ear headphones. Insert earphones: at least 55.",
				"So a LOUD beep can leak across to Lefty. That's cross-hearing!"],
			"caption_at": [0.3, 5.6],
			"teaches": "Interaural attenuation: at least 40 dB with on-ear headphones (at least 55 with inserts), so a loud air tone can reach the other cochlea.",
			"board": "A brick 'skull wall' grows between the snails with a sign '-40 dB' (a small tag: 'inserts -55'). A level meter on the cup climbs 30, 35, 70 dB and the notes get BIGGER (visual only: the sound stays soft). Each beep goes into Righty's ear AND shakes the skull: a skull-shake note runs from the cup along the skull, over Righty (never out of Righty), to the wall. Soft ones bonk and fizzle (30 - 40 and 35 - 40 are below Lefty's 5 dB). At 70 one squeezes through under the sign with a big countdown chip (70 -> 30), taps Lefty, who wakes and raises a hand, and a '70 - 40 = 30' chip holds beside him.",
			"params": {"ia": 40, "inserts_ia": 55, "levels": [30, 35, 70], "lefty_hears": 5},
			"cues": [{"t": 1.0, "sfx": "thunk", "pitch": 0.8, "vol_db": -12.0}, {"t": 3.4, "sfx": "boing", "pitch": 1.2, "vol_db": -14.0}, {"t": 4.7, "sfx": "boing", "pitch": 1.0, "vol_db": -14.0}, {"t": 6.7, "sfx": "whoosh", "pitch": 1.2, "vol_db": -14.0}, {"t": 7.8, "sfx": "chirp", "vol_db": -12.0}],
		},
		{
			"id": "bone", "set": "bone", "title": "Bone shakes it all", "duration": 10.0,
			"captions": ["A bone buzzer shakes the WHOLE skull, not just one side.",
				"Both cochleas feel it almost equally: 0 to 10 dB lost. Call it zero!"],
			"caption_at": [0.3, 4.6],
			"teaches": "Bone conduction reaches both cochleas at almost the same level (interaural attenuation about 0 dB).",
			"board": "The cup pops off; a grey bone buzzer clicks onto the bump behind Righty's ear. bzz lines; the WHOLE head jiggles like jelly and both snails vibrate the same. The wall's sign flips from '-40 dB' to '-0 dB' and the bricks turn see-through.",
			"params": {"ear": "right", "ia": 0},
			"cues": [{"t": 0.5, "sfx": "thunk", "pitch": 1.3, "vol_db": -10.0}, {"t": 1.4, "sfx": "squeak", "pitch": 0.6, "vol_db": -16.0}, {"t": 5.3, "sfx": "stamp", "pitch": 1.4, "vol_db": -12.0}],
		},
		{
			"id": "ghost", "set": "ghost", "title": "The Cross-Hearing Ghost", "duration": 10.0,
			"captions": ["Testing Righty? Lefty hears the buzz too, and if Lefty hears better, Lefty answers first.",
				"That's the Cross-Hearing Ghost: the better cochlea answering for the poorer ear."],
			"caption_at": [0.3, 5.2],
			"teaches": "The Cross-Hearing Ghost is the better cochlea answering for the poorer ear.",
			"board": "Righty (the poorer ear today) wears a nightcap. A soft buzz: Righty snores on; Lefty pops up, throws a bedsheet over itself (two eye holes, still blue), floats to Righty's side and waves an 'I HEARD IT!' flag. A big 'BOO!' bubble. Hoot gasps.",
			"params": {"poorer": "right", "better": "left"},
			"cues": [{"t": 1.2, "sfx": "squeak", "pitch": 0.6, "vol_db": -16.0}, {"t": 2.4, "sfx": "whoosh", "pitch": 0.8, "vol_db": -12.0}, {"t": 3.1, "sfx": "boing", "pitch": 0.7, "vol_db": -12.0}, {"t": 4.6, "sfx": "pop", "pitch": 0.8, "vol_db": -10.0}],
		},
		{
			"id": "mask", "set": "mask", "title": "Masking: shhh!", "duration": 10.0,
			"captions": ["Masking: a steady 'shhh' in the OTHER ear keeps it too busy to answer.",
				"The shhh goes in the non-test ear. The beep still goes to the test ear."],
			"caption_at": [0.3, 5.0],
			"teaches": "Masking puts steady noise in the non-test ear (today the better one) so it cannot answer for the test ear.",
			"board": "A blue cup pops onto Lefty's side and a purple squiggly cloud with 'shhh' letters fills Lefty's corner. Lefty puts on tiny sunglasses and dances, busy. The buzz comes: the bedsheet slides off and Righty raises its own hand. No Ghost.",
			"params": {"mask_ear": "left", "test_ear": "right"},
			"cues": [{"t": 0.5, "sfx": "pop", "pitch": 0.9, "vol_db": -8.0}, {"t": 1.0, "sfx": "whoosh", "pitch": 0.6, "vol_db": -16.0}, {"t": 6.4, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}],
		},
		{
			"id": "under", "set": "under", "title": "Too little shhh", "duration": 7.0,
			"captions": ["Too little shhh? The Ghost still sneaks through the gaps. Add more!"],
			"teaches": "Undermasking: too little noise and the non-test ear still answers.",
			"board": "The cloud shrinks to a patchy puff with holes; the Ghost peeks through a hole: 'boo!'. A noise dial on the cup shows a '+5' arrow.",
			"params": {"mask_db": 20},
			"cues": [{"t": 1.4, "sfx": "boing", "pitch": 1.4, "vol_db": -14.0}, {"t": 3.5, "sfx": "click", "vol_db": -8.0}, {"t": 4.7, "sfx": "click", "pitch": 1.2, "vol_db": -8.0}],
		},
		{
			"id": "over", "set": "over", "title": "Too much shhh", "duration": 9.0,
			"captions": ["Too much shhh? It leaks back across the skull and drowns Righty too. Overmasking!"],
			"teaches": "Overmasking: when the noise minus the interaural attenuation reaches the test ear's cochlea, it hides the test ear too.",
			"board": "The noise dial swings into the red. The cloud balloons, spills over the skull wall (its tag shrinks by 40 as it crosses) and smothers Righty, whose hand drops. A coral 'TOO MUCH NOISE!' sign wobbles. Visual only: nothing loud plays.",
			"params": {"mask_db": 80, "ia": 40},
			"cues": [{"t": 1.0, "sfx": "whoosh", "pitch": 0.5, "vol_db": -14.0}, {"t": 4.0, "sfx": "sad_trombone", "vol_db": -16.0}],
		},
		{
			"id": "plateau", "set": "plateau", "title": "The plateau", "duration": 14.0,
			"captions": ["Raise the shhh 5 dB at a time. If the answer chases the noise, the Ghost was answering.",
				"Answer holds steady through 15 dB more shhh? Plateau! That's Righty's true threshold."],
			"caption_at": [0.3, 6.6],
			"teaches": "The plateau: when the answer stays at the same level through about 15 dB more noise (three 5 dB steps), that level is the test ear's true threshold.",
			"board": "A chunky graph the AudiOtron way up: noise (dB EM) along the bottom in 5 dB steps from the start level (other ear's air + 10), the answer (dB HL) down the side, louder lower (like an audiogram). Hoot hops step by step: the first answers sink with the noise (label GHOST: chases the noise), then three hops stay level: a green FLAT LINE with a '15 dB' brace and a 'PLATEAU!' pop. After a '...' gap the line sinks again (label TOO MUCH). A soft blip per hop.",
			"params": {"rise": [[15, 15], [20, 20], [25, 25]], "flat": [[30, 25], [35, 25], [40, 25]], "over": [[70, 30], [75, 35]], "start": 15},
			"cues": [{"t": 1.6, "sfx": "blip", "pitch": 1.0, "vol_db": -12.0}, {"t": 2.4, "sfx": "blip", "pitch": 1.1, "vol_db": -12.0}, {"t": 3.2, "sfx": "blip", "pitch": 1.2, "vol_db": -12.0}, {"t": 7.0, "sfx": "blip", "pitch": 1.3, "vol_db": -12.0}, {"t": 7.8, "sfx": "blip", "pitch": 1.3, "vol_db": -12.0}, {"t": 8.6, "sfx": "blip", "pitch": 1.3, "vol_db": -12.0}, {"t": 9.0, "sfx": "sparkle", "vol_db": -10.0}, {"t": 9.2, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}, {"t": 10.6, "sfx": "blip", "pitch": 0.9, "vol_db": -14.0}, {"t": 11.2, "sfx": "blip", "pitch": 0.8, "vol_db": -14.0}],
		},
		{
			"id": "outro", "set": "outro", "title": "That's a wrap", "duration": 6.0,
			"captions": ["Busy the other ear, find the flat line. Ooh, a knock! Places, trainee!"],
			"teaches": "Recap: mask the non-test ear, trust the plateau.",
			"board": "Righty and Lefty bow; Hoot bows; a 'THE END?' card; the curtains close. Two soft knocks on the cinema door: the next patient is here.",
			"params": {},
			"cues": [{"t": 0.4, "sfx": "fanfare", "pitch": 1.2, "vol_db": -16.0}, {"t": 3.6, "sfx": "thunk", "pitch": 0.8, "vol_db": -8.0}, {"t": 3.9, "sfx": "thunk", "pitch": 0.8, "vol_db": -8.0}],
		},
	],
}

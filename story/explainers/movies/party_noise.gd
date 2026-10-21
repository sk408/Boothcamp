extends RefCounted
## Day 5's explainer: Hoot's party movie, "The Party Problem" (docs/CHAPTER5.md §4, CONTRACTS.md §9.20).
## Plays at the start of Day 5 before Marco arrives (story/level_marco.gd, the &"explainer" phase, as
## Day 2 plays the masking movie); replay from the pause menu or the title's "Hoot's Movies".
## DATA ONLY. The player types "captions", fires "cues" (quiet Sfx, seconds from the scene start) and
## hands "set" + "params" to the stage; the scenes are drawn by this movie's own sets,
## story/explainers/stages/party_noise_sets.gd (MOVIE.stage). Every scene's top-level params are its
## card (heading, lines, icon, tint: the fallback when a set is not drawn); the set's own data sits
## under params.<set>. "board" is the art brief (never shown).
## (Steve) Scene 1 opens the way Day 2's movie does: the marquee holds (params.card_hold) while Hoot
## asks the movie's question and names its answer, with two question chips (params.questions); the
## quiet cafe then runs card_hold - 2 s later.
## Facts (Steve reviews; story/tests/test_movie_party_noise.gd pins them): the voice is SIN_LEVEL_DB
## (70) and the scale's gaps are SIN_SNRS; the menu is SIN_COURSES at SIN_SNRS; typical ears follow
## half the words at SIN_NORMAL_SNR50_DB (2); the typical diner's plates are what sin_expected_words
## gives at a loss of 0.5, 25 key words right, snr_loss(25) = 0.5, band sin_band(0.5) = "normal",
## printed as SIN_BAND_NAMES: "Near-normal", never "Small" (clinical review A7). The movie never shows
## Marco's numbers, a band beyond the typical diner's, or the bill's constant: the bill is the player's.
## Written fresh for this game: every line, chatter word and course is our own, never taken from a
## published speech-in-noise test. The crowd, the babble and the loud knob are DRAWN, never played
## (CONTRACTS.md §1.3): every sound is a quiet cue.

const MOVIE: Dictionary = {
	"id": "party_noise", "title": "Hoot's party movie", "subtitle": "The Party Problem",
	"chapter": "marco", "narrator": "Hoot",
	"stage": "res://story/explainers/stages/party_noise_sets.gd",
	"scenes": [
		{
			"id": "quiet", "set": "quiet", "title": "One voice", "duration": 14.0,
			"captions": ["Hoot's Movie Matinee! Today's mystery: why can someone fine in quiet get lost at a busy table?",
				"The answer is SNR LOSS. Quiet beeps can't show it, so we test words in noise.",
				"In a quiet room, one voice is easy to follow."],
			"caption_at": [0.3, 4.4, 8.4],
			"teaches": "What the movie answers (why someone who does fine in quiet gets lost at a busy table: SNR loss, which quiet beeps cannot show, so we test words in noise), then: in quiet, one talker is easy to follow.",
			"board": "Curtains swish open (0.1-1.2 s) on the marquee HOOT'S MOVIE MATINEE / The Party Problem, a little cafe table with a candle and two speech bubbles beside the title; it holds 8 s while Hoot asks the question and names the answer, with two question chips under it. Then the card flips away on a quiet cafe: a window with the moon, a lamp over a small table, two beans with tiramisu. Her big crisp bubble: 'Shall we share the tiramisu?' His bubble: a happy tick; a chip: 'One voice, no crowd: easy!'. Reduced motion: no sway, things fade in.",
			"params": {"heading": "The Party Problem", "icon": "", "tint": "#ffe9c7",
				"lines": ["Fine in quiet, lost at a party?", "A quiet room: one voice", "Easy to follow"],
				"card_hold": 8.0, "questions": ["Why is a busy table so hard?", "How do we test words in noise?"],
				"quiet": {"title": "The Party Problem", "starring": "starring a voice and a crowd",
					"line": "Shall we share the tiramisu?"}},
			"cues": [{"t": 0.2, "sfx": "fanfare", "vol_db": -14.0}, {"t": 0.5, "sfx": "whoosh", "pitch": 0.9, "vol_db": -12.0}, {"t": 2.0, "sfx": "pop", "pitch": 1.0, "vol_db": -10.0}, {"t": 4.6, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 8.8, "sfx": "pop", "pitch": 1.1, "vol_db": -10.0}, {"t": 10.2, "sfx": "chirp", "pitch": 1.2, "vol_db": -14.0}],
		},
		{
			"id": "crowd", "set": "crowd", "title": "Add a crowd", "duration": 8.0,
			"captions": ["Add a crowd. Her voice didn't change. The noise did."],
			"caption_at": [0.3],
			"teaches": "Background talk (babble) makes the same voice harder to follow.",
			"board": "The same cafe fills: six tables pop in, two at a time, each with two grey diners and their grey chatter bubbles ('haha', 'clink!', 'more bread?'...), then a waiter weaves across the front with a tray. Her bubble is the same size and says the same thing, but chatter bubbles crowd over it; his face goes puzzled with a '?'. Chips: 'Her voice: the SAME' and 'The noise: MORE'. The chatter is drawn only, never played. Reduced motion: the tables fade in, the waiter stands still.",
			"params": {"heading": "Add a crowd", "icon": "", "tint": "#f2e6d8",
				"lines": ["Same voice, same loudness", "More noise all around it", "Now it's hard to follow"],
				"crowd": {"tables": 6, "line": "Shall we share the tiramisu?",
					"chatter": ["haha", "clink!", "more bread?", "no way!", "cheers!", "mmm", "and then...", "ha-ha!", "pass the oil", "really?", "my cousin...", "happy birthday!"]}},
			"cues": [{"t": 0.8, "sfx": "pop", "pitch": 0.9, "vol_db": -12.0}, {"t": 1.5, "sfx": "pop", "pitch": 1.0, "vol_db": -12.0}, {"t": 2.2, "sfx": "pop", "pitch": 1.1, "vol_db": -12.0}, {"t": 2.9, "sfx": "whoosh", "pitch": 1.2, "vol_db": -14.0}],
		},
		{
			"id": "scale", "set": "scale", "title": "SNR: the gap", "duration": 9.0,
			"captions": ["SNR: how much louder the voice is than the noise. A bigger gap is easier."],
			"caption_at": [0.3],
			"teaches": "SNR (signal-to-noise ratio) is the gap in dB between the voice and the noise.",
			"board": "A big kitchen balance. Left pan: one plate, VOICE 70. Right pan: a stack of grey plates, PARTY 45; the beam tips to the voice, and a gold bracket between the two pans reads SNR 25 dB. More plates land on the party side: 55 (SNR 15), then 65 (SNR 5); the beam levels and the bracket shrinks each time. Then: 'Smaller gap: harder to follow'. Reduced motion: the plates and the beam change in cuts.",
			"params": {"heading": "SNR: the gap", "icon": "", "tint": "#fff2dc",
				"lines": ["Voice 70, party 45: SNR 25", "Party 55: SNR 15", "Party 65: SNR 5", "Smaller gap: harder to follow"],
				"scale": {"voice": 70, "party": [45, 55, 65], "at": [1.0, 3.6, 6.0]}},
			"cues": [{"t": 1.0, "sfx": "ding", "pitch": 1.2, "vol_db": -12.0}, {"t": 3.6, "sfx": "ding", "pitch": 1.35, "vol_db": -12.0}, {"t": 6.0, "sfx": "ding", "pitch": 1.5, "vol_db": -12.0}],
		},
		{
			"id": "knob", "set": "knob", "title": "Louder isn't the fix", "duration": 8.0,
			"captions": ["Turn everything up? Both get louder. The gap stays the same."],
			"caption_at": [0.3],
			"teaches": "Turning everything up keeps the SNR the same.",
			"board": "Hoot cranks a giant volume knob. Beside it, two bars like the SPEECH screen's SNR-O-METER: VOICE (mint) and PARTY (grey), with the gold SNR bracket between their tops. Both bars grow 10 dB (voice 70 to 80, party 65 to 75) with drawn loud-lines; the bracket rides up and stays SNR 5 dB: 'STILL 5 dB!'. Drawn only: nothing gets louder.",
			"params": {"heading": "Louder isn't the fix", "icon": "dial", "tint": "#fff2dc",
				"lines": ["Turn both up 10 dB", "Voice 80, party 75", "The gap is still 5"],
				"knob": {"voice": [70, 80], "party": [65, 75]}},
			"cues": [{"t": 1.0, "sfx": "click", "vol_db": -10.0}, {"t": 1.6, "sfx": "click", "pitch": 1.2, "vol_db": -10.0}, {"t": 4.2, "sfx": "boing", "pitch": 0.9, "vol_db": -14.0}],
		},
		{
			"id": "gap", "set": "gap", "title": "SNR loss", "duration": 9.0,
			"captions": ["Most ears need a small gap. Some need a bigger one. That extra gap is SNR loss."],
			"caption_at": [0.3],
			"teaches": "SNR loss: how much bigger a gap a listener needs than typical ears, to follow half the words.",
			"board": "Split screen, the same noisy table on both sides. Left: a diner with typical ears gets half the words at a 2 dB gap (two of his four word tiles crisp, two crumbs). Right: the other diner's tiles all crumble into breadcrumbs at 2 dB; his gap widens to 10 dB and now half are crisp. Between them, a ruler from 2 to 10 marks the extra 8 dB: SNR LOSS. Reduced motion: no crumbling, the tiles change in cuts.",
			"params": {"heading": "SNR loss", "icon": "", "tint": "#eef3ff",
				"lines": ["Typical ears: half the words", "at a gap of just 2 dB", "Some ears need a bigger gap", "The extra gap is SNR loss"],
				"gap": {"typical_snr50": 2, "other_snr50": 10, "words": ["Try", "the", "lemon", "cake!"], "crisp": [0, 2]}},
			"cues": [{"t": 1.2, "sfx": "pop", "vol_db": -12.0}, {"t": 2.6, "sfx": "squeak", "pitch": 0.8, "vol_db": -16.0}, {"t": 4.4, "sfx": "boing", "pitch": 0.8, "vol_db": -14.0}, {"t": 5.8, "sfx": "ding", "pitch": 1.1, "vol_db": -12.0}],
		},
		{
			"id": "menu", "set": "menu", "title": "Six courses", "duration": 8.0,
			"captions": ["The Party Noise Test: six sentences, five key words each. The party grows every time."],
			"caption_at": [0.3],
			"teaches": "The Party Noise Test: six sentences of five key words, the babble one step louder each time (SNR 25 down to 0).",
			"board": "A restaurant menu unfolds: THE PARTY NOISE TEST, six courses: Starter 25, Soup 20, Fish 15, Main 10, Cheese 5, Dessert 0 (SNR, dB), each with five green peas for its key words. Tiny diners crowd the margins more with every course, and an arrow down the side reads 'the party grows'. Reduced motion: the rows appear without the unfold.",
			"params": {"heading": "The Party Noise Test", "icon": "", "tint": "#ffe9c7",
				"lines": ["6 sentences, 5 key words each", "The party grows each time", "SNR 25, 20, 15, 10, 5, 0"],
				"menu": {"title": "THE PARTY NOISE TEST", "key_words": 5,
					"courses": [["Starter", 25], ["Soup", 20], ["Fish", 15], ["Main", 10], ["Cheese", 5], ["Dessert", 0]]}},
			"cues": [{"t": 0.6, "sfx": "whoosh", "pitch": 1.1, "vol_db": -12.0}, {"t": 2.0, "sfx": "blip", "vol_db": -14.0}, {"t": 4.6, "sfx": "blip", "pitch": 1.2, "vol_db": -14.0}],
		},
		{
			"id": "receipt", "set": "receipt", "title": "The bill", "duration": 8.0,
			"captions": ["Every key word missed costs about 1 dB. The receipt adds up the SNR loss."],
			"caption_at": [0.3],
			"teaches": "Each missed key word adds 1 dB to the SNR loss (a typical listener misses about four or five).",
			"board": "A till receipt prints for a diner with typical hearing: Starter 5, Soup 5, Fish 5, Main 5, Cheese 4, Dessert 1; KEY WORDS RIGHT 25; the bottom line reads SNR LOSS 0.5 dB, then a stamp: NEAR-NORMAL. Beside it, his plates: the missed peas roll off the Cheese and Dessert plates, each into a little '+1 dB' tag. Reduced motion: the receipt prints at once, the peas do not roll.",
			"params": {"heading": "The bill", "icon": "", "tint": "#fffbf2",
				"lines": ["Each missed key word: +1 dB", "Typical diner: 25 of 30", "SNR loss 0.5 dB: near-normal"],
				"receipt": {"courses": ["Starter", "Soup", "Fish", "Main", "Cheese", "Dessert"], "key_words": 5,
					"counts": [5, 5, 5, 5, 4, 1], "total": 25, "loss": 0.5, "band": "normal", "band_name": "NEAR-NORMAL"}},
			"cues": [{"t": 1.0, "sfx": "pen", "vol_db": -14.0}, {"t": 4.0, "sfx": "kaching", "vol_db": -12.0}, {"t": 4.8, "sfx": "stamp", "pitch": 1.1, "vol_db": -12.0}],
		},
		{
			"id": "tonight", "set": "tonight", "title": "Tonight's guest", "duration": 7.0,
			"captions": ["Beeps are tested in silence. Dinner isn't silent. So we test the party too!"],
			"caption_at": [0.3],
			"teaches": "Tone audiograms are measured in quiet; speech-in-noise testing measures the real complaint.",
			"board": "An audiogram card (beeps in a silent booth: 'shh') beside the noisy table; a question mark hops between them. Two knocks on a door at the back; it swings open on a silhouette with a tucked-in napkin and a raised fork: TONIGHT. The curtains close: 'Places, trainee: a guest!'. Reduced motion: no hop, the door cuts open.",
			"params": {"heading": "Tonight's guest", "icon": "hoot", "tint": "#ffe9c7",
				"lines": ["Beeps: tested in silence", "Dinner: never silent", "So we test the party too"],
				"tonight": {"guest": "napkin_silhouette", "sign": "TONIGHT", "chip": "Places, trainee: a guest!"}},
			"cues": [{"t": 0.4, "sfx": "pop", "vol_db": -12.0}, {"t": 2.6, "sfx": "thunk", "pitch": 0.8, "vol_db": -8.0}, {"t": 2.9, "sfx": "thunk", "pitch": 0.8, "vol_db": -8.0}, {"t": 3.3, "sfx": "door", "vol_db": -12.0}, {"t": 5.4, "sfx": "fanfare", "pitch": 1.2, "vol_db": -16.0}],
		},
	],
}

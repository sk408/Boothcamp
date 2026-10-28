extends RefCounted
## PracticalDeck (training, story-internal): The Practical's stations, cheat-sheet cards and card
## generators (docs/training/PRACTICAL_EXAM.md, research in docs/training/CA_PRACTICAL_EXAM.md). Pure
## data and pure functions. The exam's own numbers (the 12-month calibration, the 10 oz bottle, age 18,
## the one-year and ten-year subject rules) are named here with the board document they come from;
## clinical numbers come from ClinicRules / CaseRules.
##   const PracticalDeck := preload("res://story/training/practical/practical_deck.gd")
##   PracticalDeck.kit_round(rng)   # six honest "Pack the bag" cards
## A card is {kind, title, options: [words], answer: index, lines: [two lines], hint, ...kind's own keys}.

const LESSON := "practical"

## The eight stations, in the real exam's order (all open). built: playable in this version; the others
## show SOON in the Training room until their PR lands. card: the cheat-sheet card it earns (Station 2
## earns a second, card2).
const STATIONS: Array = [
	{"id": "kit", "num": 1, "name": "Pack the bag", "pitch": "Your kit, checked. No sharing.", "color": Color("#7d8398"),
		"card": "kit_bag", "built": true, "movie": "",
		"intro": "On exam day you bring your own kit and your own subject. Nothing is shared, nothing is lent.\n"
			+ "Spot what stays home, pick an audiometer in calibration, run the listening check, and choose a subject who qualifies."},
	{"id": "hands", "num": 2, "name": "Steady hands", "pitch": "Brace it. Look. Refer?", "color": Color("#3a9d76"),
		"card": "safe_support", "card2": "refer_8", "built": false, "movie": "",
		"intro": "Hands, head and light: one unit. Then look, and decide: test, impression, or a doctor first?"},
	{"id": "tones", "num": 3, "name": "Station A: the tones", "pitch": "Air, bone, mask, record.", "color": Color("#2d6cdf"),
		"card": "station_a", "built": false, "movie": "",
		"intro": "Air and bone on a live subject, masked by the plateau, every symbol on the chart."},
	{"id": "td", "num": 4, "name": "Too loud?", "pitch": "Threshold of discomfort.", "color": Color("#f2b632"),
		"card": "td_steps", "built": false, "movie": "",
		"intro": "Watch the face, not the dial. Pairs of beeps, up 5 at a time, until the hand goes up."},
	{"id": "impression", "num": 5, "name": "One good impression", "pitch": "Dam, fill, cure, judge.", "color": Color("#ff9f1c"),
		"card": "impression", "built": false, "movie": "",
		"intro": "One impression only. No air in the tip, no voids, past the second bend."},
	{"id": "delivery", "num": 6, "name": "Delivery day", "pitch": "Retube, fit, counsel.", "color": Color("#1f9aa5"),
		"card": "delivery", "built": false, "movie": "",
		"intro": "Same bend, same length. Then fit the RIC and tell the truth, kindly."},
	{"id": "bench", "num": 7, "name": "The bench", "pitch": "Look, listen, test, fix.", "color": Color("#8e5cc4"),
		"card": "bench_tree", "built": false, "movie": "",
		"intro": "A dead aid, a weak one, a whistler. Find the fault, fix it or send it in."},
	{"id": "exam", "num": 8, "name": "Exam day", "pitch": "Two rooms, the whole job.", "color": Color("#e5383b"),
		"card": "", "built": false, "movie": "",
		"intro": "Room A, then Room B. Scripted examiners, no hints. Finish for the Booth Camp Practical licence."},
]

## The cheat-sheet cards in pin order.
const CARD_ORDER: Array[String] = ["kit_bag", "safe_support", "refer_8", "station_a", "td_steps", "impression", "delivery", "bench_tree"]

## Holes in a station's round.
const ROUND_HOLES := 6

## Every lesson card says this (PRACTICAL_EXAM.md §5).
const DISCLAIMER := "Our own practice exam, built from the board's public outline. The real one may differ: check the board's latest bulletin."


static func station(id: String) -> Dictionary:
	for s: Dictionary in STATIONS:
		if String(s["id"]) == id:
			return s
	return {}


static func station_ids() -> Array[String]:
	var out: Array[String] = []
	for s: Dictionary in STATIONS:
		out.append(String(s["id"]))
	return out


## The station that earns a card (its number), for an unearned card's "Station N".
static func card_station(card_id: String) -> int:
	for s: Dictionary in STATIONS:
		if String(s["card"]) == card_id or String(s.get("card2", "")) == card_id:
			return int(s["num"])
	return 0


## A cheat-sheet card: {id, title, color, ink, lines}.
static func cheat_card(id: String) -> Dictionary:
	match id:
		"kit_bag":
			return {"id": id, "title": "Kit Bag", "color": Color("#c9ccd6"), "ink": Palette.INK,
				"lines": ["Audiometer: cal. in %d months." % CAL_MONTHS, "Over-ear phones. Bone. Otoscope.",
					"One-piece syringe or hand gun.", "Dams. In-date material. Tube.", "Gel %d oz max. No-bleach wipes." % SANITIZER_MAX_OZ]}
		"safe_support":
			return {"id": id, "title": "Safe Support", "color": Color("#5bc8a3"), "ink": Palette.INK,
				"lines": ["Bridge hand on the head.", "Instrument hand braced.", "Hands, head, light: one unit."]}
		"refer_8":
			return {"id": id, "title": "California Refer 8", "color": Color("#e5383b"), "ink": Palette.PAPER,
				"lines": ["Deformity. Drainage (90 d).", "Sudden loss (90 d). Dizzy.", "One-sided sudden loss.", "Big air-bone gap. Wax/object.", "Pain."]}
		"station_a":
			return {"id": id, "title": "Station A Order", "color": Color("#f2b632"), "ink": Palette.INK,
				"lines": ["Check. Wash. Look.", "Air, better ear first. Bone.", "Mask: plateau. TD. Record."]}
		"td_steps":
			return {"id": id, "title": "TD Steps", "color": Color("#ffd23f"), "ink": Palette.INK,
				"lines": ["Face in view. Top pitch first.", "Start 70. Pairs. Up 5.", "Finger: annoying. Hand: stop.", "No hand at max: arrow at 110."]}
		"impression":
			return {"id": id, "title": "Impression Steps", "color": Color("#ff9f1c"), "ink": Palette.INK,
				"lines": ["Look. Tell. Dam past 2nd bend.", "Check. Express to the tip.", "Canal, then concha. Cure.", "Break seal. Out. Look again."]}
		"delivery":
			return {"id": id, "title": "Delivery", "color": Color("#1f9aa5"), "ink": Palette.PAPER,
				"lines": ["Retube: same bend, same length.", "RIC: wire and dome fit.", "Teach in and out.", "Expectations: real and kind."]}
		"bench_tree":
			return {"id": id, "title": "Bench Tree", "color": Color("#8e5cc4"), "ink": Palette.PAPER,
				"lines": ["Look. Listen. Test. Fix.", "Can't fix? Send it in.", "Can't send? Replace."]}
	return {}


static func hole_name(strokes: int) -> String:
	match strokes:
		1:
			return "Par"
		2:
			return "Bogey"
		3:
			return "Double bogey"
	return "Triple bogey"


static func round_name(over_par: int) -> String:
	return "Even par" if over_par <= 0 else "+%d" % over_par


# ================================================================ Station 1: Pack the bag

## The bulletin's equipment rules (Candidate Information Bulletin, March 2025, p. 3; CA_PRACTICAL_EXAM.md §3.3):
## the audiometer's calibration within the last 12 months, sanitizer no larger than 10 oz.
const CAL_MONTHS := 12
const SANITIZER_MAX_OZ := 10
## The subject rules (same bulletin, p. 3): 18 or older; not a subject in the past year; no licence, job
## or exam-coaching link in hearing aid dispensing or audiology in the past 10 years; clean ears.
const SUBJECT_MIN_AGE := 18
const SUBJECT_GAP_YEARS := 1
const SUBJECT_LOOKBACK_YEARS := 10

## The kit table. ok: it goes in the clear bag; a decoy (ok false) carries why it stays home.
const ITEMS: Dictionary = {
	"audiometer": {"name": "Audiometer + cal. papers", "ok": true},
	"phones": {"name": "Over-ear headphones", "ok": true},
	"bone": {"name": "Bone oscillator", "ok": true},
	"otoscope": {"name": "Otoscope", "ok": true},
	"earlight": {"name": "Ear light", "ok": true},
	"syringe": {"name": "One-piece clear syringe", "ok": true},
	"gun": {"name": "Hand impression gun", "ok": true},
	"material": {"name": "Impression material", "ok": true},
	"dams": {"name": "Ear dams, 3 sizes", "ok": true},
	"tube": {"name": "Listening tube", "ok": true},
	"gel": {"name": "Hand gel, 8 oz", "ok": true},
	"wipes": {"name": "Wipes, no bleach", "ok": true},
	"inserts": {"name": "Insert earphones", "ok": false, "why": "The exam asks for over-ear (non-insert) headphones."},
	"tip_syringe": {"name": "Syringe, snap-on tip", "ok": false, "why": "Only a clear one-piece syringe, or a non-electric gun."},
	"e_gun": {"name": "Electric impression gun", "ok": false, "why": "No electric guns: a hand gun or a one-piece syringe."},
	"bleach": {"name": "Bleach wipes", "ok": false, "why": "Wipes must be non-bleach."},
	"jumbo_gel": {"name": "Hand gel, 32 oz", "ok": false, "why": "Sanitizer bottles: %d oz or smaller." % SANITIZER_MAX_OZ},
	"old_material": {"name": "Material, EXP 2019", "ok": false, "why": "Check the date: expired material stays home."},
	"watch": {"name": "Wristwatch", "ok": false, "why": "No watches in the room: the site keeps the time."},
	"phone": {"name": "Phone", "ok": false, "why": "Phones stay in the car."},
	"notes": {"name": "Cheat sheet", "ok": false, "why": "No notes or books. Your hands know it."},
}

## The listening check's findings, in answer order (keys 1-4).
const FIXES: Array[String] = ["cord", "swap", "bone", "fine"]
const FIX_WORDS: Dictionary = {"cord": "Fix the cord", "swap": "Swap the cups", "bone": "Change the bone oscillator", "fine": "All good: start"}
const FAULTS: Dictionary = {
	"cord": {"symptom": "You wiggle the red cord: the beep crackles and cuts out.",
		"lines": ["A crackle that follows the cord is the cord.", "Fix or swap it before the subject sits down."]},
	"swap": {"symptom": "RIGHT selected, 1000 Hz: the beep comes out of the BLUE cup.",
		"lines": ["The cups are on the wrong sides: red goes on the right ear.", "Swap them now, and check again."]},
	"bone": {"symptom": "BONE selected, 500 Hz: nothing, even held to your own mastoid.",
		"lines": ["No buzz from the oscillator: change or reconnect it.", "Bone thresholds need a working oscillator."]},
	"fine": {"symptom": "Both cups clear at every pitch, no crackle, and the bone buzzes.",
		"lines": ["Clean listening check: you're ready.", "Do it every time, before every subject."]},
}

## Possible subjects. ok: they qualify; why: the bulletin's rule behind the answer.
const SUBJECTS: Array = [
	{"id": "rosa", "name": "Rosa, 70", "line": "Your neighbour. You checked her ears Tuesday: clean.", "ok": true,
		"why": "Over 18, no hearing-care ties, clean ears. A good subject."},
	{"id": "dev", "name": "Dev, 34", "line": "Your friend from soccer. Never worked in hearing care.", "ok": true,
		"why": "An adult with no hearing-care ties. Check his ears this week."},
	{"id": "may", "name": "Aunt May, 58", "line": "Clean ears, no ear problems, free on Saturday.", "ok": true,
		"why": "Family is fine: an adult with clean, healthy ears."},
	{"id": "kim", "name": "Kim, 17", "line": "Your cousin's kid. Keen to help!", "ok": false,
		"why": "Subjects must be %d or older, with photo ID." % SUBJECT_MIN_AGE},
	{"id": "priya", "name": "Priya, 41", "line": "A licensed audiologist since 2015.", "ok": false,
		"why": "No audiology or dispensing licence in the past %d years." % SUBJECT_LOOKBACK_YEARS},
	{"id": "tom", "name": "Tom, 52", "line": "He was a subject at the March exam.", "ok": false,
		"why": "Not a subject in the past %d year: he sits this one out." % SUBJECT_GAP_YEARS},
	{"id": "lee", "name": "Lee, 29", "line": "Worked at a hearing aid maker until last year.", "ok": false,
		"why": "No manufacturer or dispensing job in the past %d years." % SUBJECT_LOOKBACK_YEARS},
	{"id": "sam", "name": "Sam, 63", "line": "His left ear has been running since Monday.", "ok": false,
		"why": "Subjects need clean ears with no medical problems."},
	{"id": "jo", "name": "Jo, 45", "line": "Teaches a practical-exam prep class.", "ok": false,
		"why": "No exam coaching or training links in the past %d years." % SUBJECT_LOOKBACK_YEARS},
]
const SUBJECT_WORDS: Array[String] = ["Yes, bring them", "No, ask someone else"]

## Calibration stickers: months back from the exam (in date: within CAL_MONTHS).
const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
## The exam's month in the stickers' story: March 2027, as a month count (year * 12 + month index).
const EXAM_MONTH := 2027 * 12 + 2

## Hoot's guided cards (Try it): only the right answer is open, and Hoot says why.
const KIT_TRIES: Array = [
	{"kind": "tray", "items": ["phones", "inserts", "otoscope", "bone"],
		"line": "Which one stays home? The exam wants over-ear headphones. Inserts stay home!"},
	{"kind": "listen", "fault": "swap",
		"line": "The listening check: red should sound in the right cup. It doesn't, so swap the cups."},
]


static func month_word(m: int) -> String:
	return "%s %d" % [MONTHS[posmod(m, 12)], floori(m / 12.0)]


## "Which one stays home?": three kit items and one decoy, in the given order.
static func tray_card(items: Array) -> Dictionary:
	var answer := -1
	var names: Array[String] = []
	for i in items.size():
		var it: Dictionary = ITEMS[String(items[i])]
		names.append(String(it["name"]))
		if not bool(it["ok"]):
			answer = i
	var decoy: Dictionary = ITEMS[String(items[answer])]
	return {"kind": "tray", "title": "Which one stays home?", "items": items.duplicate(), "options": names, "answer": answer,
		"lines": [String(decoy["why"]), "The other three go in the clear bag."],
		"hint": "Three of these the bulletin lists. One breaks a rule: the type, the size, the date, or no electronics."}


## "Which audiometer can come?": three stickers, one inside CAL_MONTHS of the exam.
static func sticker_card(good_back: int, bad_backs: Array, order: Array) -> Dictionary:
	var backs: Array[int] = [good_back]
	for b: Variant in bad_backs:
		backs.append(int(b))
	var shown: Array[int] = []
	for i: Variant in order:
		shown.append(backs[int(i)])
	var words: Array[String] = []
	for b: int in shown:
		words.append("Calibrated %s" % month_word(EXAM_MONTH - b))
	var answer := shown.find(good_back)
	return {"kind": "sticker", "title": "Which audiometer can come?", "backs": shown, "options": words, "answer": answer,
		"exam": month_word(EXAM_MONTH),
		"lines": ["%s is %d months before the exam: inside %d." % [month_word(EXAM_MONTH - good_back), good_back, CAL_MONTHS],
			"Bring the papers: the serial number must match the audiometer."],
		"hint": "Count back from the exam in %s. Calibration must be within the last %d months." % [month_word(EXAM_MONTH), CAL_MONTHS]}


## The listening check: a symptom, and what to do.
static func listen_card(fault: String) -> Dictionary:
	var f: Dictionary = FAULTS[fault]
	var words: Array[String] = []
	for x: String in FIXES:
		words.append(String(FIX_WORDS[x]))
	return {"kind": "listen", "title": "The listening check", "fault": fault, "symptom": String(f["symptom"]), "options": words,
		"answer": FIXES.find(fault), "lines": (f["lines"] as Array).duplicate(),
		"hint": "Listen through each cup, wiggle each cord, buzz the bone. Which part misbehaves?"}


## Can they be your subject?
static func subject_card(s: Dictionary) -> Dictionary:
	return {"kind": "subject", "title": "Can they be your subject?", "subject": String(s["id"]), "who": String(s["name"]),
		"about": String(s["line"]), "ok": bool(s["ok"]), "options": SUBJECT_WORDS.duplicate(), "answer": 0 if bool(s["ok"]) else 1,
		"lines": [String(s["why"]), "The board approves your subject before the exam."],
		"hint": "Adult, no hearing-care ties for ten years, not a subject this past year, clean healthy ears."}


static func subject(id: String) -> Dictionary:
	for s: Dictionary in SUBJECTS:
		if String(s["id"]) == id:
			return s
	return {}


## The Try it cards, built.
static func kit_tries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for t: Dictionary in KIT_TRIES:
		var c := tray_card(t["items"]) if String(t["kind"]) == "tray" else listen_card(String(t["fault"]))
		c["line"] = String(t["line"])
		out.append(c)
	return out


## Six honest cards: two trays (different decoys), a sticker, a listening check, two subjects (one who
## qualifies, one who doesn't, in either order).
static func kit_round(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var goods: Array[String] = []
	var decoys: Array[String] = []
	for id: String in ITEMS:
		(goods if bool(ITEMS[id]["ok"]) else decoys).append(id)
	_shuffle(goods, rng)
	_shuffle(decoys, rng)
	var out: Array[Dictionary] = []
	for t in 2:
		var items: Array = [goods[t * 3], goods[t * 3 + 1], goods[t * 3 + 2]]
		items.insert(rng.randi_range(0, 3), decoys[t])
		out.append(tray_card(items))
	var order: Array = [0, 1, 2]
	_shuffle(order, rng)
	out.append(sticker_card(rng.randi_range(2, CAL_MONTHS - 2), [rng.randi_range(CAL_MONTHS + 2, CAL_MONTHS + 8), rng.randi_range(2 * CAL_MONTHS, 3 * CAL_MONTHS)], order))
	out.append(listen_card(FIXES[rng.randi_range(0, FIXES.size() - 1)]))
	var yes: Array = []
	var no: Array = []
	for s: Dictionary in SUBJECTS:
		(yes if bool(s["ok"]) else no).append(s)
	var pair: Array[Dictionary] = [subject_card(yes[rng.randi_range(0, yes.size() - 1)]), subject_card(no[rng.randi_range(0, no.size() - 1)])]
	if rng.randi_range(0, 1) == 1:
		pair.reverse()
	out.append_array(pair)
	return out


## The cards of a station's round.
static func deal(station_id: String, rng: RandomNumberGenerator) -> Array[Dictionary]:
	match station_id:
		"kit":
			return kit_round(rng)
	return []


static func tries(station_id: String) -> Array[Dictionary]:
	match station_id:
		"kit":
			return kit_tries()
	return []


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t

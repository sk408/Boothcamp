# Case scripts

Generated from `story/cases/*.json` by `python3 tools/case_scripts.py`. Do not edit by hand: change the
JSON and run the tool again. Every Hoot line is 18 words or fewer (`story/tests/test_cases.gd`). Choices
are shown in file order; the game shuffles them.

## Rocco Rimshot's Case (`noise_notch`)

**The call:** FIT

### Intro
- **Rocco:** Ba-dum-TSS! Rocco Rimshot, drummer of The Decibelles. Thirty years behind the kit, not one earplug!
- *(Hoot: gasp)*
- **Hoot:** Thirty years of cymbals and no earplugs? My feathers just curled.
- *(patient: confused)*
- **Rocco:** My bandmates' jokes have lost their punchlines. In noisy pubs I laugh at the wrong bits.
- **Rocco:** And my ears ring like a cymbal that never stops.
- **Hoot:** Ringing ears and lost punchlines. Let's investigate! Questions first.

Always on the notes: *30 years of loud drumming, no earplugs*; *Lost in noisy pubs*; *Constant high ringing, both ears*

### History (pick one per round)

| Question | Pts | Answer | Clue card | Hoot |
|---|---|---|---|---|
| R1: Is it worse in quiet, or in noise? | 2 | Quiet chat's fine. Noisy pub, I laugh at the wrong bits. | Fine in quiet, lost in noise | Hearing but not understanding: the high pitches carry the consonants. |
| R1: What's your favourite drum? | 0 | The cowbell. Criminally underrated. |  | Groovy, but not a clue. Ask about his hearing! |
| R1: Which ear is worse? | 1 | About the same. Maybe the left: that's my hi-hat side. | Both ears, about the same |  |
| R2: Any ear pain, drainage, dizziness, or sudden change? | 2 | No pain, no gunk, no spinning. It crept up over the years. | No pain, drainage, dizziness or sudden change |  |
| R2: When was your last loud gig? | 1 | Saturday. Nothing loud since. My neighbours are thrilled. | No loud sound for 4 days | Good. Right after loud sound, hearing can dip for a day or two. |
| R2: Can you do a drum solo for me? | 0 | *drums on the desk* Ba-da-ba-da-ba-da TSSSS! ...What was the question? |  | Groovy, but not a clue. Ask about his hearing! |

Red-flag sweep (if skipped): **Hoot:** Always check the red flags: pain, drainage, dizziness, sudden or fluctuating change, one ear only. **Rocco:** None of those. It crept up, year after year, gig after gig.

Red-flag card: *Pain, drainage, dizziness, sudden change: NONE.*

- **Hoot:** Crept up slowly, no red flags so far. Let's look inside!

### Otoscopy
First caption: *Fresh speculum. Rocco's LEFT ear first: a clear canal, a healthy eardrum.*

Caption: *Rocco's RIGHT ear: a roomy canal, shiny eardrum.*

- **Hoot:** Roomy canals, healthy eardrums. No drumsticks stuck in there either.
- **Rocco:** You'd be surprised what ends up in a drummer's ear.
- Card: *Canals clear, eardrums normal*

### Tympanometer
Tip: large (roomy canal). Right: type A, peak -15 daPa, 0.9 mL, canal 1.5 mL. Left: type A, peak -10 daPa, 0.8 mL, canal 1.6 mL.

Question: **What type are both of Rocco's tympanograms?** (A / B / C, shuffled)
- A wrong pick: Hoot: Type X would be (its shape). Look where the peak sits, and how tall.

- **Hoot:** Type A both sides: no fluid, no blockage. The bone test will tell us if it's deeper.

### Instructions
- **Hoot:** This morning's listening check: every beep clean, the button works. Dials stay out of view.
- **Hoot:** Tell him: press for every beep, even faint ones. Not for the cymbal in his head!
- **Rocco:** Beeps yes, ringing no. Got it, boss.
- **Hoot:** Tip: with ringing ears, pulsed beeps stand out from the ring. Most audiometers can pulse them.

### Test plan
- Right AC (player for 6 stamps, then Hoot): "Right ear's yours, up to 8k. Watch what happens between 4k and 8k!"
- Left AC (Hoot at x8): "Left ear at Hoot speed. Same pattern?"
- Right BC (Hoot at x8): "Bone check at Hoot speed: middle ear or inner ear?"
  - before:
    - **Hoot:** Now the bone buzzer, on his right: is it the middle ear, or deeper?
- Then masked bone and masked air wherever the rules ask (Hoot). When masked bone ran and no ear needed masked air: **Hoot:** At these levels, air tones can't cross the head. Only bone needed masking today!

After the tests (said when every ear with bone agrees with the case; otherwise **Hoot:** Bone's in. Let's lay it over the air and see what it says.):

- **Hoot:** Bone sits right on the air: no gap. Not the middle ear.

### The chart, the shape question, the reveal
- **Hoot:** Here's Rocco's chart, trainee. What shape do you see?
- **Question:** What shape is Rocco's hearing loss?
  - (right) A notch: a dip at 4k that recovers at 8k.
  - A ski slope: worse and worse up to 8k.: Hoot: Look at 8k: it climbs back up. A ski slope keeps going down.
  - Rising: worse in the low pitches.: Hoot: His low pitches are fine. Look at the right side of the chart.
- *(the notch comes alive: NOISE NOTCH)*
- **Hoot:** Dip at 4k, back up at 8k: a noise notch. It points to years of loud sound.
- **Rocco:** So my drums wrote their name in my ears?
- **Hoot:** Pretty much. The damage so far is permanent. More damage is preventable.
- **Hoot:** Noise notches usually sit between 3k and 6k, deepest near 4k.

Cards from the chart: *Dip at 4k, better at 8k (noise notch)*; *Left and right ears match* (if the ears match); *Bone matches air: no gap*

If the chart and the truth disagree on any of those: **Hoot:** Some stamps wandered, so the chart and the story disagree. In clinic, recheck first!

### The call
- **FIT** (right): No red flags and a real need: aids help, though noisy pubs stay tricky. Earplugs every gig!
- **REFER**: Careful is good! But no red flags: ears match, no pain, no spins, nothing sudden.
- **DOCTOR TODAY**: Nothing sudden: it crept up over thirty years of drumming. Not an emergency.

**Present the evidence: why is it safe to fit Rocco today?**
- Proof cards (tags): no_red_flags, symmetric, both_ears. Right: Exactly! History, exam and chart all clear, and ears that match: fitting is the right call.
- Wrong card (default): True, but it doesn't prove he's safe to fit. Look for the red-flag check!
  - noise_years: That's why he has a loss, not why it's safe to fit. Find the red-flag check!
  - noise_trouble: That's why he WANTS hearing aids. What shows it's safe to fit them?
  - notch: That's the pattern, not the safety check. Find the red-flag check!
  - ear_clear: True: no wax, drainage or deformity today. Past drips, pain, dizziness, sudden change: which clue clears those?
  - tymp_a: True: no fluid, no blockage. Which clue clears past drips, pain, dizziness and sudden change?
  - snhl: True: no air-bone gap, one red flag cleared. Which clue clears past drips, pain, dizziness and sudden change?

### Payoff
- **Hoot:** We fit because his hearing trips him up at the pub.
- **Hoot:** Same chart, no trouble yet? Counsel, earplugs, and a recheck in a year.
- **Hoot:** Hearing aids tuned for the high pitches. They often make the ringing less noticeable, too.
- **Hoot:** A full fitting also checks words in each ear.
- *(hearing aids)*
- *(patient: cheer)*
- **Rocco:** Whoa. I can hear the hi-hat AND my bandmates' terrible jokes!
- **Hoot:** Now protect what's left: earplugs at every gig AND every rehearsal.
- **Choice:** Which earplugs for a drummer?
  - Cotton wool (0 pts): Hoot: Cotton wool? It barely blocks a thing, and it just fell in the snare.
  - Foam earplugs (1 pts): Hoot: Foam works, but it cuts the highs more than the lows. A drummer wants it even.
  - Filtered musicians' earplugs (2 pts): Hoot: A filter turns pitches down more evenly than foam: cymbals still sound like cymbals. Rock on!
- **Hoot:** On stage: hearing aids out, earplugs in. And a hearing check every year.
- **Rocco:** Earplugs in. Ba-dum-TSS!

### The Daily Decibel
- S: **DRUMMER'S NOTCH NAILED; OWL PRESCRIBES EARPLUGS** A textbook notch at 4k, charted cleanly. The Decibelles buy musicians' earplugs in bulk.
- A: **ROCCO HEARS HI-HAT AGAIN; PUB DEMANDS QUIETER SOLOS** No red flags and a real need: fit, then protect what's left.
- B: **NOTCH FOUND, DRUMMER FITTED, CYMBALS ON NOTICE** The notch showed up; a few stamps wandered. Hoot recommends practice.
- C: **SOME BEEPS DROPPED THE BEAT, CONFIRMS OWL** Look for the dip at 4k and the comeback at 8k.
- Do-over: **ROCCO BACK FOR AN ENCORE; BRINGS DRUMSTICKS** Noise notches hide between 3k and 6k. Rocco will be back next Friday.
- First stamp REFER (S to C): **DRUMMER REFERRED FOR BEING A DRUMMER; OWL OVERRULES** No red flags and ears that match: Rocco could be fitted today.
- First stamp DOCTOR TODAY (S to C): **ROCCO RUSHED TO DOCTOR; DOCTOR ASKS FOR A DRUM SOLO** Thirty years of slow change is not an emergency.

## Captain Marina Gale's Case (`menieres`)

**The call:** REFER

### Intro
- **Marina:** Ahoy! Captain Marina Gale, island ferry. Last Tuesday my kitchen rolled more than my boat!
- *(Hoot: wing up)*
- **Hoot:** A captain who gets seasick on dry land? Now that's a case file.
- **Marina:** Steady as a rock today, touch wood.
- *(patient: confused)*
- **Marina:** But my left ear's full of seawater, and it roars like the engine room. Some days it's nearly fine.
- **Hoot:** A full, roaring ear with good days and bad. Let's hear the whole story.

Always on the notes: *Left ear: full, low roar, good days and bad days*

### History (pick one per round)

| Question | Pts | Answer | Clue card | Hoot |
|---|---|---|---|---|
| R1: Does your hearing change from day to day? | 2 | Yes! Some days the left is fine. Then a spell comes and it's underwater again. | Hearing comes and goes | Hearing that comes and goes. Remember that one! |
| R1: Do you get seasick on boats? | 0 | Never! I once ate a fish pie in a force nine gale. |  | Shipshape answer, but not a clue. Ask about her ears! |
| R1: Any noise in the ear? | 1 | A low roar, like the engine room. It gets louder before a spell. | Low roar in the left ear, louder before a spell |  |
| R2: Any pain, drainage, dizziness, or sudden change? | 2 | No pain, no drips. But the room SPINS: two or three hours at a time, four times since spring. / Last one ten days ago. Good days since, and no new drop. | Room-spinning spells for hours |  |
| R2: Have you had a cold or a blocked nose lately? | 1 | Not a sniffle all year. Sea air! | No cold or blocked nose | Good: a cold can clog the middle ear and muffle hearing for a while. |
| R2: What's the best sea shanty? | 0 | Anything with a chorus. Ten verses minimum. |  | Shipshape answer, but not a clue. Ask about her ears! |

Red-flag sweep (if skipped): **Hoot:** Always check the red flags: pain, drainage, dizziness, sudden or fluctuating change, one ear only. **Marina:** No pain, no drips. But the room SPINS: two or three hours at a time, four times since spring. / Last one ten days ago. Good days since, and no new drop.

Red-flag card: *Dizziness: YES, spinning spells. / One ear only: YES = see a doctor.*
; extra card: *Last spell 10 days ago; good days since*

- **Marina:** Oh! I brought my hearing test from my spring sea medical. It's on file.
- **Hoot:** Brilliant! Old results are gold. We'll compare them with today's.

### Otoscopy
First caption: *Fresh speculum. Marina's RIGHT ear first: a clear canal, a healthy eardrum.*

Caption: *Marina's LEFT ear: an average-sized canal, shiny eardrum.*

- **Hoot:** Clear canals, healthy eardrums. No seawater, no barnacles.
- **Marina:** Barnacles! You laugh, but I've seen things.
- Card: *Canals clear, eardrums normal*

### Tympanometer
Tip: medium (average-sized canal). Right: type A, peak 0 daPa, 0.7 mL, canal 1.2 mL. Left: type A, peak -15 daPa, 0.6 mL, canal 1.1 mL.

Question: **Her ear feels full. Is it fluid behind the eardrum?**
- (right) No: type A, a normal peak. No fluid.
- Yes: it's flat, type B.: Hoot: Flat with a normal canal volume would point to fluid. Hers has a normal peak.
- Yes: type C, negative pressure.: Hoot: Her peaks sit near zero. A type C sits far to the left.

- **Hoot:** No fluid behind that drum. The bone test will tell us where the fullness lives.

### Instructions
- **Hoot:** This morning's listening check: every beep clean, the button works. Dials stay out of view.
- **Hoot:** Tell her: press for every beep, even faint ones. Not for the roar!
- **Marina:** Beeps yes, engine room no. Aye aye!
- **Hoot:** Tip: with a roaring ear, pulsed beeps stand out better. Most audiometers can pulse them.

### Test plan
- Right AC (Hoot at x8): "Better ear first, like the pros. I'll zip through the right!"
- Left AC (player for 8 stamps, then Hoot): "Left ear's all yours. Keep an eye on the low pitches!"
- Right BC (Hoot at x8): "Right ear at Hoot speed: bone for her better cochlea."
  - before:
    - **Hoot:** Bone buzzer on her better ear first: the right. Unmasked bone answers for her better cochlea.
- Then masked bone and masked air wherever the rules ask (Hoot). When masked bone ran and no ear needed masked air: **Hoot:** At these levels, air tones can't cross the head. Only bone needed masking today!

After the tests (said when every ear with bone agrees with the case; otherwise **Hoot:** Bone's in. Let's lay it over the air and see what it says.):

- **Hoot:** Masked bone sits with the air: no gap. Not the middle ear.

### The chart, the shape question, the reveal
- **Hoot:** Here's today's chart. What does her left ear show?
- **Question:** What does Marina's left ear show?
  - (right) Rising: worst in the LOW pitches.
  - A noise notch at 4k.: Hoot: No dip at 4k: her high pitches are nearly fine.
  - A ski slope: worst in the high pitches.: Hoot: Look left on the chart: the low pitches are the worst.
- *(the rising comes alive: LOW PITCHES DOWN)*
- **Hoot:** Low pitches about 25 dB worse than spring, and she has good days: hearing that comes and goes.
- **Marina:** So my ear has tides?
- **Hoot:** Something like tides. An ear doctor can find out why.
- **Hoot:** A low-pitch loss in one ear, worse than in spring.

Cards from the chart: *Left ear only* (if the ears differ); *Hearing comes and goes*; *Low pitches 25 dB worse than in spring*; *Bone matches air: no gap*

If the chart and the truth disagree on any of those: **Hoot:** Some stamps wandered, so the chart and the story disagree. In clinic, recheck first!

### The call
- **FIT**: Drop anchor! Dizziness is a red flag. Doctor first; hearing aids may help later, between spells.
- **REFER** (right): Spins, a full roaring ear, hearing with tides: set course for the ear doctor!
- **DOCTOR TODAY**: Her hearing dips with spells and comes back. No new drop that's stayed down. Soon, not today.

**Present the evidence: why does Marina need a doctor first?**
- Proof cards (tags): spinning, left_only, fluctuating, changed, left_full, roar. Right: Exactly! Dizziness and a one-sided, changing loss: a doctor looks first.
- Wrong card (default): True, but that's not a red flag. What would worry a doctor?
  - ear_clear: Those are normal: they don't send her to a doctor.
  - tymp_a: Those are normal: they don't send her to a doctor.
  - snhl: That's the type of loss. What's on the red-flag list?
  - no_cold: No cold is good news. What's on the red-flag list?
  - last_spell: That's why it's not TODAY. What sends her to a doctor at all?

### Payoff
- *(boat)*
- **Hoot:** Today's chart and the spring one, side by side, sailing to the ear doctor.
- **Hoot:** I'll ask for an ear doctor appointment this week, not someday.
- **Hoot:** Hearing drops and doesn't come back? Doctor that day. Weakness, numbness, double vision or slurred speech? Emergency!
- **Marina:** Aye. And then maybe something for the hearing?
- **Hoot:** Exactly. Hearing aids can help between spells, once the doctor has had a look.
- *(patient: cheer)*
- **Marina:** Aye aye. My first mate takes the wheel till the doctor clears me.

### The Daily Decibel
- S: **CAPTAIN'S SPINNING SPELLS SPOTTED; OWL SALUTES SHARP TRAINEE** A rising loss, a spring comparison and a clean chart. The ferry runs on time.
- A: **FERRY CAPTAIN STEERED TO EAR DOCTOR; LOW TIDE IN LEFT EAR** Dizziness plus a one-sided, changing loss: a doctor looks first.
- B: **MARINA REFERRED; TRAINEE FINDS SEA LEGS** The rising pattern showed; a few stamps drifted.
- C: **SOME BEEPS LOST AT SEA, CONFIRMS OWL** Watch the low pitches, and compare with old results.
- Do-over: **MARINA BACK TOMORROW, FIRST MATE AT THE WHEEL; BRINGS FISH PIE** Spinning plus one ear: always a doctor first.
- First stamp FIT (S to C): **TRAINEE NEARLY FITS A SPINNING CAPTAIN; OWL GRABS THE WHEEL** Dizziness and a one-sided, changing loss: a doctor looks first.
- First stamp DOCTOR TODAY (S to C): **MARINA SEEN SAME DAY; DOCTOR: NO HARM CHECKING, BUT THIS WEEK WAS FINE** Her hearing dips with spells and returns: soon, not today.

## Dash Delgado's Case (`sudden`)

**The call:** DOCTOR TODAY

### Intro
- **Dash:** Dash Delgado: owner, chef AND only driver of Speedy Slice! Hot or it's free. Can we do this in twenty?
- *(Hoot: wing up)*
- **Hoot:** A pizza boss in a hurry! We'll be quick AND careful, Dash.
- *(patient: confused)*
- **Dash:** I woke up yesterday and my right ear was just... gone. Probably wax. Can you be quick?
- *(Hoot: gasp)*
- **Hoot:** Gone overnight? Hold on to your pizza. This could matter a lot.

Always on the notes: *Right ear went overnight, yesterday morning*

### History (pick one per round)

| Question | Pts | Answer | Clue card | Hoot |
|---|---|---|---|---|
| R1: Exactly when did it start? | 2 | Yesterday, when I woke up. There was a pop, then whooshing. About thirty hours ago? | Pop, then whooshing: about 30 hours ago | Thirty hours. Sooner is better, so let's keep moving! |
| R1: What's the best pizza topping? | 0 | Pineapple. Fight me. Actually, don't, I'm busy. |  | Tasty, but not a clue. Ask about his ear! |
| R1: Has your hearing ever done this before? | 1 | Never. The right was perfect until yesterday. I hear my scooter fine with the left. | First time ever: right ear fine until yesterday |  |
| R2: Any pain, drainage, or dizziness? | 2 | No pain, no drips. A bit wobbly yesterday, fine now. Just the whoosh. | No pain or drainage |  |
| R2: Have you tried cleaning it out? | 1 | I tried a cotton bud. Nothing came out. Pretty sure it's wax though. | Tried a cotton bud: nothing came out | Never poke in there! And 'probably wax' is a guess. We'll look. |
| R2: Can I get a free pizza? | 0 | Only if it arrives cold. Mine never do. Which is why we must HURRY. |  | Tasty, but not a clue. Ask about his ear! |

Red-flag sweep (if skipped): **Hoot:** Always check the red flags: pain, drainage, dizziness, sudden or fluctuating change, one ear only. **Dash:** No pain, no drips. A bit wobbly yesterday, fine now. Just the whoosh.

Red-flag card: *Sudden, one ear, yesterday: YES. Dizzy too. / See a doctor. How soon? You decide.*
; extra card: *Wobbly yesterday: dizziness*

- **Hoot:** Any face droop, numbness, slurred speech or double vision? Those mean the ER now.
- **Dash:** None of that. Just the ear.
- **Hoot:** A sudden loss in one ear, yesterday. Quick AND careful: let's look.

### Otoscopy
First caption: *Fresh speculum. Dash's LEFT ear first: a clear canal, a healthy eardrum.*

Caption: *Dash's RIGHT ear: an average-sized canal. No wax at all!*

- **Hoot:** Clear canal, healthy eardrum. Not a speck of wax!
- *(patient: startle)*
- **Dash:** No wax? Then what's blocking it?
- **Hoot:** Maybe nothing is blocking it. Let's check the middle ear next.
- Card: *Canal clear: no wax*

### Tympanometer
Tip: medium (average-sized canal). Right: type A, peak -5 daPa, 0.8 mL, canal 1.3 mL. Left: type A, peak 0 daPa, 0.9 mL, canal 1.3 mL.

Question: **Dash says it's wax. Does the tymp agree?**
- (right) No: a normal peak and a normal canal volume.
- Yes: it's flat, like a wax plug.: Hoot: A wax plug gives a flat line and a small canal volume. His peak is normal.
- A tymp can't tell.: Hoot: It can spot a full plug: flat line, tiny canal volume. Partial wax still needs the otoscope.

- **Hoot:** Type A both sides: no fluid, no wax plug. The bone test shows if it's deeper.

### Instructions
- **Hoot:** This morning's listening check: every beep clean, the button works. Dials stay out of view.
- **Hoot:** Tell him: press for every beep, even faint ones. No racing the beeps!
- **Dash:** Beeps only. Fast but accurate. Like my deliveries!

### Test plan
- Left AC (Hoot at x8): "Better ear first, like the pros. Left at Hoot speed!"
- Right AC (player for 3 stamps, then Hoot): "Right ear's yours. Start at 1k, as always."
- Left BC (Hoot at x8): "Left ear at Hoot speed: bone for his better cochlea."
  - before:
    - **Hoot:** Wax would block air, not bone: bone settles it. Buzzer on his better ear first: the left.
- Then masked bone and masked air wherever the rules ask (Hoot). When masked bone ran and no ear needed masked air: **Hoot:** At these levels, air tones can't cross the head. Only bone needed masking today!

After the tests (said when every ear with bone agrees with the case; otherwise **Hoot:** Bone's in. Let's lay it over the air and see what it says.):

- **Hoot:** Masked bone is in. Let's see where it landed.

### The chart, the shape question, the reveal
- **Hoot:** One ear down overnight. Now: where did the masked bone land?
- **Question:** What type of loss is Dash's right ear?
  - (right) Sensorineural: bone is down with the air.
  - Conductive: blocked, like wax.: Hoot: Then bone would be near normal. His masked bone is down with the air.
  - Mixed: a bit of both.: Hoot: Mixed needs a gap too. His bone and air sit together.
  - (graded against the type of loss in the right ear)
- *(the flat_one comes alive: ONE EAR, OVERNIGHT)*
- **Hoot:** Right ear needs 40 to 60 dB, left ear normal. One ear, overnight.
- **Dash:** So it's not wax?
- **Hoot:** Not wax, not fluid: bone is down too. That's what makes it urgent.
- **Hoot:** Sooner is better. Doctors still treat after three days, but today beats tomorrow.
- **Hoot:** Sensorineural and sudden: the inner ear or nerve changed overnight.

Cards from the chart: *Right ear down, bone too: inner ear or nerve*; *Left ear normal*

### The call
- **FIT**: Hold the pizza! A brand-new sudden loss needs a doctor first, and today.
- **REFER**: A normal referral means days or weeks. A sudden loss can't wait: TODAY.
- **DOCTOR TODAY** (right): Hot delivery! Sudden sensorineural loss is urgent: treatment works best early. Doctor TODAY!

**Present the evidence: why TODAY and not in a few days?**
- Proof cards (tags): sudden, onset, first_time, one_ear_snhl, dizzy. Right: Exactly! Sudden, one ear, inner ear or nerve: the doctor sees him today.
  - dizzy: Yes! Dizzy with a sudden loss: another red flag. Today.
- Wrong card (default): True, but that wouldn't make it a rush. What makes it urgent?
  - no_wax: No wax rules out a plug. What makes it a rush?
  - tymp_a: That rules out fluid and wax. What makes it a rush?
  - cotton_bud: Never poke in there! But that's not the rush. Look again.
  - red_flag_check: No pain is good news. What makes it urgent?
  - left_normal: That's his good ear. What happened to the other one?

### Payoff
- *(phone)*
- **Hoot:** Hoot here, Booth Camp. Sudden loss in the right ear since yesterday. Can you see him today?
- **Hoot:** Three o'clock? Perfect. His audiogram is on its way to you now.
- **Hoot:** Dash, the ear doctor sees you at three. Go straight there, pizzas or not.
- **Hoot:** No ear doctor free today? Then the emergency department. Same day, either way.
- **Hoot:** Sudden means over three days or less. Within a month, no wax or fluid to blame? Doctor today.
- *(patient: cheer)*
- **Dash:** Same day? Faster than my pizzas! Thanks, owl!

### The Daily Decibel
- S: **SUDDEN LOSS SPOTTED IN RECORD TIME; PIZZA STILL HOT** One ear, overnight, bone down too: a same-day referral. Sooner was better.
- A: **PIZZA BOSS RUSHED TO EAR DOCTOR SAME DAY; TOPPINGS DEBATE CONTINUES** A sudden one-sided loss can't wait: doctor today.
- B: **DASH SENT TO DOCTOR TODAY; OWL CHECKS WATCH** Sent to the doctor today; a few stamps wandered.
- C: **SOME BEEPS ARRIVED COLD, CONFIRMS OWL** Sudden plus sensorineural means doctor today.
- Do-over: **TRAINEE DEMANDS REMATCH; DASH ALREADY AT THE DOCTOR** Remember: sudden hearing loss is urgent, even after three days. Dash made his appointment anyway.
- First stamp FIT (S to C): **TRAINEE OFFERS PIZZA BOSS HEARING AIDS; OWL DROPS HIS SLICE** A brand-new sudden loss goes to a doctor today, not a fitting.
- First stamp REFER (S to C): **DASH BOOKED FOR NEXT WEEK; OWL PHONES AHEAD ANYWAY** Sudden sensorineural loss can't wait for a routine referral.

## Ginger Snapp's Case (`cookie_bite`)

**The call:** FIT

### Intro
- **Ginger:** Good evening, Booth Camp! Ginger Snapp, ventriloquist. And this is my partner...
- **Chip:** Chip! The cookie with the bite. Don't ask what happened to my head.
- *(Hoot: gasp)*
- **Hoot:** Her lips didn't move! A talking cookie, trainee. Stay focused.
- *(patient: confused)*
- **Chip:** She keeps missing what the audience shouts. Hecklers get away with MURDER.
- **Ginger:** Voices keep dropping out. I just smile, nod and let Chip do the talking.
- **Hoot:** Words going missing from voices. Let's investigate! Questions first.

Always on the notes: *Voices drop out; she smiles and nods*

### History (pick one per round)

| Question | Pts | Answer | Clue card | Hoot |
|---|---|---|---|---|
| R1: How long has your hearing been like this? | 2 | Since school! The school hearing tests found it. It hasn't really changed since. | Found at school; the same ever since | Found at school and steady since. Hold on to that clue! |
| R1: What's Chip's best joke? | 0 | (Chip) Why did the cookie see a doctor? It felt crummy! I'm here all week. |  | Showbiz gold, but not a clue. Ask about her hearing! |
| R1: Does anyone in your family have hearing trouble? | 2 | My dad, and his mum, Grandma Snapp. Their hearing tests look just like mine. | Dad and his mum have the same pattern | A pattern down the family line. Worth knowing! |
| R2: Any ear pain, drainage, dizziness, or sudden change? | 2 | None of those. Same as ever. I just need to hear the hecklers now. | No pain, drainage, dizziness or sudden change |  |
| R2: Is it both ears? | 1 | Both, about the same. Chip says my left is worse, but he's biased. | Both ears, about the same |  |
| R2: Can Chip sing? | 0 | (Chip) Laaa-la-LAAAA! Thank you, thank you. Autographs later. |  | Showbiz gold, but not a clue. Ask about her hearing! |

Red-flag sweep (if skipped): **Hoot:** Always check the red flags: pain, drainage, dizziness, sudden or fluctuating change, one ear only. **Ginger:** None of those. Same as ever. I just need to hear the hecklers now.

Red-flag card: *Pain, drainage, dizziness, sudden change: NONE.*

- **Chip:** Show 'em the old chart, Ginger!
- **Ginger:** Oh! My hearing test from nine years ago. Chip never lets me lose it.
- **Hoot:** Old results are gold! No red flags so far. Let's take a look.

### Otoscopy
First caption: *Fresh speculum. Ginger's LEFT ear first: a clear canal, a healthy eardrum.*

Caption: *Ginger's RIGHT ear: a narrow canal, shiny eardrum.*

- **Hoot:** Narrow canals, healthy eardrums. Nothing hiding in there.
- **Chip:** Not even a chocolate chip? I'm insulted.
- Card: *Canals clear, eardrums normal*

### Tympanometer
Tip: small (narrow canal). Right: type A, peak -10 daPa, 0.7 mL, canal 1.0 mL. Left: type A, peak -5 daPa, 0.6 mL, canal 1.0 mL.

Question: **Is her middle ear the problem?**
- (right) No sign of it: type A, both sides.
- Yes: flat, type B.: Hoot: Flat with a normal canal volume would point to fluid. Hers have normal peaks.
- Yes: type C, negative pressure.: Hoot: Her peaks sit near zero. A type C sits far to the left.

- **Hoot:** Type A both sides: no fluid, no blockage. The bone test decides if it's deeper.

### Instructions
- **Hoot:** This morning's listening check: every beep clean, the button works. Dials stay out of view.
- **Hoot:** Tell her: press for every beep, even faint ones. Chip doesn't get a button.
- **Chip:** Discrimination! I'm calling my agent.
- **Ginger:** Beeps only. Got it.

### Test plan
- Right AC (player for 8 stamps, then Hoot): "Right ear's yours. Watch the middle pitches!"
  - after it, if the stamps asked for 750 Hz (and it is on the chart):
    - **Hoot:** Extra stop at 750! A 500-to-1k jump of 20 dB or more gets tested in between.
    - **Hoot:** Hearing aids care exactly where her loss begins. Now we know.
- Left AC (Hoot at x8): "Left ear at Hoot speed. Same shape?"
- Right BC (Hoot at x8): "Bone check at Hoot speed: middle ear or inner ear?"
  - before:
    - **Hoot:** Now the bone buzzer: middle ear, or deeper?
- Then masked bone and masked air wherever the rules ask (Hoot). When masked bone ran and no ear needed masked air: **Hoot:** At these levels, air tones can't cross the head. Only bone needed masking today!

After the tests (said when every ear with bone agrees with the case; otherwise **Hoot:** Bone's in. Let's lay it over the air and see what it says.):

- **Hoot:** Bone sits right on the air: no gap. Not the middle ear.

### The chart, the shape question, the reveal
- **Hoot:** Here's her chart. What shape do you see?
- **Question:** What shape is Ginger's hearing loss?
  - (right) A cookie bite: worst in the middle pitches.
  - A ski slope: worst in the high pitches.: Hoot: Look at 4k and 8k: they come back up.
  - A noise notch at 4k.: Hoot: Her dip is wider and at lower pitches: 1k to 2k, not 4k.
- *(the cookie comes alive: COOKIE BITE)*
- **Chip:** Hey, that's MY look!
- **Hoot:** Worse in the middle, better at both ends: a cookie bite! These often run in families.
- **Ginger:** So that's why Chip and I get along.
- **Hoot:** And her right ear matches her chart from nine years ago. Stable.
- **Hoot:** The middle pitches carry lots of speech, so words drop out of voices.

Cards from the chart: *Worst in the middle pitches (cookie bite)*; *Left and right ears match* (if the ears match); *Bone matches air: no gap*; *Right ear matches nine years ago: stable*

If the chart and the truth disagree on any of those: **Hoot:** Some stamps wandered, so the chart and the story disagree. In clinic, recheck first!

### The call
- **FIT** (right): Sweet call! Stable for years, ears match, no red flags: hearing aids tuned for the middle pitches.
- **REFER**: Family history isn't a red flag. Ears match, nothing sudden: fit her, and offer a genetics chat.
- **DOCTOR TODAY**: Since SCHOOL? That's the opposite of sudden! No emergency here.

Present the evidence: **Her dad and grandma have it too. Why is it still safe to fit her?**
- Proof cards (tags): no_red_flags, symmetric, both_ears, stable, stable_chart. Right: Exactly! History, exam and chart all clear, stable and matching: fitting is the right call.
- Wrong card (default): True, but it doesn't show she's safe to fit. Look for the red-flag check!
  - family: That's family history, not a red flag. What shows it's safe?
  - ear_clear: True: no wax, drainage or deformity today. Past drips, pain, dizziness, sudden change: which clue clears those?
  - tymp_a: True: no fluid, no blockage. Which clue clears past drips, pain, dizziness and sudden change?
  - snhl: True: no air-bone gap, one red flag cleared. Which clue clears past drips, pain, dizziness and sudden change?
  - voices_drop: That's what's wrong, not why it's safe. Look for the red-flag check!
  - cookie: That's what's wrong, not why it's safe. Look for the red-flag check!

### Payoff
- **Hoot:** Hearing aids tuned for the middle pitches: right where her bite is.
- **Hoot:** A full fitting also checks words in each ear.
- *(hearing aids)*
- *(patient: cheer)*
- **Ginger:** Oh! I can hear the back row. Even the hecklers!
- **Chip:** Where are MY hearing aids?
- **Hoot:** It runs in families: offer a genetic counselling referral. Not a red flag, so no need to wait.
- **Hoot:** And a hearing check every year: some family patterns slowly change.
- **Chip:** Same time next year, owl. Bring snacks.

### The Daily Decibel
- S: **COOKIE BITE CRACKED; PUPPET DEMANDS CREDIT** A textbook cookie bite, stable for nine years, charted cleanly.
- A: **VENTRILOQUIST HEARS THE BACK ROW AGAIN; CHIP STEALS THE SHOW** Stable, matching ears, no red flags: fit, tune for the middle, offer a genetics chat.
- B: **MIDDLE PITCHES FOUND, GINGER FITTED; CHIP UNIMPRESSED** The bite showed up; a few stamps missed their cue.
- C: **SOME BEEPS MISSED THEIR CUE, CONFIRMS OWL** Look for the dip between 1k and 2k.
- Do-over: **GINGER AND CHIP BOOKED FOR AN ENCORE** Cookie bites sit in the middle pitches. Family history alone isn't a red flag.
- First stamp REFER (S to C): **VENTRILOQUIST REFERRED FOR FAMILY HISTORY; CHIP OBJECTS** Family history isn't a red flag: stable and symmetric, she can be fitted.
- First stamp DOCTOR TODAY (S to C): **GINGER RUSHED TO DOCTOR; CHIP ASKS 'FOR WHAT?'** Stable for years is the opposite of sudden.

## Barnaby Bumble's Case (`wax`)

**The call:** REFER

### Intro
- **Barnaby:** Bzzz-good morning! Barnaby Bumble, beekeeper. Forty thousand bees, and every one of them is called Gerald.
- *(Hoot: wing up)*
- **Hoot:** Forty thousand Geralds! Welcome, Barnaby. What brings you in?
- *(patient: confused)*
- **Barnaby:** My bees have gone quiet, and everyone mumbles. I'm sixty-one: hearing aid time! I've brought my wallet.
- *(Hoot: gasp)*
- **Hoot:** Wallet away for now! Age isn't a diagnosis. Clues first.

Always on the notes: *Sure he needs hearing aids: brought his wallet*; *His bees sound quiet; people mumble*

### History (pick one per round)

| Question | Pts | Answer | Clue card | Hoot |
|---|---|---|---|---|
| R1: Which ear is worse, and since when? | 2 | The right. Muffly for months, then last week in the shower... FWUMP. Like a cork went in. | Right: muffly for months, then FWUMP in the shower | One ear, and water made it worse. Interesting! Let's keep digging. |
| R1: Do you clean your ears? | 1 | Every morning, with a cotton bud. Right in, deep as it goes. Squeaky clean! | Cotton buds, deep, every morning | Cotton buds push wax deeper. Nothing smaller than your elbow goes in your ear! |
| R1: Do your bees have names? | 0 | All forty thousand. Gerald, Gerald, Gerald... Gerald. Big family. |  | Sweet, but not a clue. Ask about his ears! |
| R2: Any pain, drainage, dizziness, or sudden change? | 2 | No pain, no drips, no spins. But the right went all at once, in the shower. Is that sudden? | No pain, drainage or dizziness |  |
| R2: Have you tried anything to fix it? | 1 | A hairpin. And an ear candle I made from my own beeswax! | Tried a hairpin and an ear candle | Hairpins scratch. Ear candles don't clean anything, and they can burn. Never again, please! |
| R2: Can I try some honey? | 0 | Here: a jar of Bumble's Best, straight from my pocket. Careful, Gerald's guarding it. |  | Sweet, but not a clue. Ask about his ears! |

Red-flag sweep (if skipped): **Hoot:** Always check the red flags: pain, drainage, dizziness, sudden or fluctuating change, one ear only. **Barnaby:** No pain, no drips, no spins. But the right went all at once, in the shower. Is that sudden?

Red-flag card: *Sudden change, one ear: YES. Pain, drainage, dizziness: none. / See a doctor. How soon? You decide.*
; extra card: *Right ear blocked all at once, in the shower*

- **Hoot:** Sudden and one-sided: that can be urgent. Or it can be simpler. Let's look!
- **Barnaby:** Look all you like. You'll see a man who needs hearing aids!

### Otoscopy
First caption: *Fresh speculum. Barnaby's LEFT ear first: a clear canal, a healthy eardrum.*

Caption: *Barnaby's RIGHT ear: a roomy canal... packed solid with wax.* (view: wax)

- **Hoot:** That's a wall of wax! I can't even see the eardrum.
- *(patient: startle)*
- **Barnaby:** Wax? Is it... beeswax?
- **Hoot:** Very much your own. Cotton buds pack it in like a cork.
- **Hoot:** Usually wax comes out before testing. Today we'll measure first, to see its toll.
- Card: *Right canal packed with wax: no eardrum in view* (red card)

### Tympanometer
Tip: large (roomy canal). Right: type B, flat, canal 0.4 mL: reads blocked. Left: type A, peak -10 daPa, 0.8 mL, canal 1.5 mL.

Question: **His right is flat. What does the canal volume say?**
- (right) Blocked: the probe faces a wall of wax.
- Fluid behind the eardrum.: Hoot: Fluid gives a flat line with a NORMAL canal volume. His is tiny: 0.4 mL.
- A hole in the eardrum.: Hoot: A hole makes the canal volume BIG. His is tiny: the probe met wax.

- **Hoot:** The probe is talking to a wall of wax, not an eardrum. Left side: normal.
- **Hoot:** A gentle seal at the entrance, never a push. Many clinics skip the probe on a packed canal.

### Instructions
- **Hoot:** This morning's listening check: every beep clean, the button works. Dials stay out of view.
- **Hoot:** Headphones today, not foam inserts: they go deep, and could push the wax further.
- **Hoot:** Tell him: press for every beep, even faint ones. Gerald waits outside.
- **Barnaby:** Hear that, Gerald? Out. Shoo. Sorry, he's clingy.

### Test plan
- Left AC (Hoot's montage): "Better ear first, like the pros. Hoot's montage: the left in a flash!"
- Right AC (player for 2 stamps, then Hoot): "Right ear's yours: the side that went quiet. Start at 1k."
- Left BC (Hoot's montage): "Hoot's montage: bone on his good left ear!"
  - before:
    - **Hoot:** Bone mostly skips the canal and middle ear. Better ear first: the buzzer goes on his left.
- Then masked bone and masked air wherever the rules ask (Hoot). When masked bone ran and no ear needed masked air: **Hoot:** At these levels, air tones can't cross the head. Only bone needed masking today!

After the tests (said when every ear with bone agrees with the case; otherwise **Hoot:** Bone's in. Let's lay it over the air and see what it says.):

- **Hoot:** Masked bone's in, Ghost chased off. Now: bone against air!

### The chart, the shape question, the reveal
- **Hoot:** Here's Barnaby's chart. Look at the right ear's bone, then its air.
- **Question:** What type of loss is Barnaby's right ear?
  - Sensorineural: bone is down with the air.: Hoot: Look at the bone: near normal. Only the air is down.
  - (right) Conductive: bone fine, air blocked.
  - Mixed: bone down AND a gap.: Hoot: Mixed needs bone down too. His bone is near normal.
  - (graded against the type of loss in the right ear)
- *(the gap comes alive, with the wax in the gap: BONE FINE, AIR BLOCKED)*
- **Hoot:** Bone near normal, air about 25 dB worse: an air-bone gap. Sound is stuck at the door.
- **Barnaby:** Stuck? Like a bee in a jam jar?
- **Hoot:** Just like that. And the cochlea behind the plug is fine, waiting for sound.
- **Hoot:** Conductive: something stops sound before it reaches a healthy inner ear.

Cards from the chart: *Right: bone normal, air down: a gap* (only when the chart reads conductive); *Right ear only: a clear difference* (red card) (if the ears differ); *Gap of 15+ dB at 500, 1k and 2k* (red card) (only with a gap of 15+ at 500, 1k and 2k)

If the chart and the truth disagree on any of those: **Hoot:** Some stamps wandered, so the chart and the story disagree. In clinic, recheck first!

### The call
- **FIT**: Hold the honey! No hearing aid works through a plug. Wax out first, then retest.
- **REFER** (right): Right! Lots of wax is a red flag: out by a doctor or trained clinician, then we retest.
- **DOCTOR TODAY**: The wax explains the sudden block, and his bone is normal. Soon, not today.

**Present the evidence: what shows something is blocking the sound?**
- Proof cards (tags): wax_plug, tymp_blocked, gap, abg_flag. Right: Exactly! Something's blocking the sound: wax out by a doctor or trained clinician, then we retest.
  - wax_plug: Yes! A lot of wax is a red flag. A plug can hide more: we'll retest.
  - tymp_blocked: Yes! Flat with a tiny canal volume: the probe tone met the plug. Wax out first.
  - gap: Yes! Bone is fine, air is blocked: the plug costs him that gap.
  - abg_flag: Yes! His gap tops 15 dB at 500, 1k and 2k: a red flag. Wax out first.
- Wrong card (default): True, but that doesn't show the sound is blocked. Look again!
  - wants_aids: That's why he WANTS aids. What shows something's in the way first?
  - cotton_buds: That's how it got packed in. What shows the sound is blocked?
  - bees_quiet: That's what he notices. What shows the sound is blocked?
  - sudden_block: Sudden, yes, and the wax explains it. What shows the sound is blocked?
  - right_only: One ear sends him to a doctor. But what shows the sound is blocked?
  - right_blocked: That's the story. Which look or test shows the sound is blocked?
  - home_fixes: Never again, please! But what shows the sound is blocked?
  - red_flag_check: Good news, but it doesn't show the sound is blocked. Look again!

### Payoff
- *(letter)*
- **Hoot:** A note for your doctor: wax plug, right ear, bone normal. They'll clear it safely.
- **Hoot:** They may suggest softening drops for a few days, then a gentle rinse or suction.
- **Barnaby:** But my wallet's all warmed up!
- **Hoot:** Keep it in your pocket. You might not need hearing aids at all.
- **Hoot:** Until then: no cotton buds, no hairpins. Beeswax candles go on the table only!
- **Hoot:** Pain, drips or dizziness before then? See a doctor that day.
- *(patient: nod)*
- **Barnaby:** Promise. Gerald's my witness.

### The retest: *A WEEK LATER* (unscored)
- **Barnaby:** Bzzz-back again! And look what the doctor's nurse got out!
- *(wax jar)*
- *(Hoot: gasp)*
- **Hoot:** That's... a LOT of wax. And definitely not beeswax.
- **Barnaby:** It came out with a THWOP. It's going on the mantelpiece.

Otoscopy again:
Caption: *Barnaby's RIGHT ear, wax-free: a roomy canal, a shiny eardrum.*

- **Hoot:** Hello, eardrum! Pearly grey, cone of light, all present.

Tymp again (the tip seals, no question): Right: type A, peak -10 daPa, 0.7 mL, canal 1.6 mL. Left: type A, peak -10 daPa, 0.8 mL, canal 1.5 mL.

- **Hoot:** A normal mountain now, and the canal volume jumped from 0.4 to 1.6. The plug's gone!

- **Choice:** Wax out. Where will his right-ear air land now?
  - Up near his bone line, about 10. (2 pts): Hoot: Yes! Normal bone said so: take away the plug and air climbs to bone.
  - Right where it was, about 35. (0 pts): Hoot: The plug made that gap. No plug, no gap. Try again!
  - Even lower than before. (0 pts): Hoot: Removing a plug shouldn't hurt hearing. Think about his bone!
- **Hoot:** Same deal: press for every beep. Let's see what the wax was hiding.

- Right AC (player for 1 stamp, then Hoot): "Right ear again! You take 1k. Where will it land this time?"

- *(the new chart flies up over the old one, dashed "WITH WAX": UNPLUGGED!)*
- When the measured right ear agrees with the story:
  - *(patient: cheer)*
  - **Barnaby:** The BEES! I can hear the bees again! Gerald, you're LOUD!
  - **Hoot:** Air came up to meet the bone: about 25 dB better. Normal hearing, right ear!
- Otherwise: **Hoot:** Much better with the plug out. A few stamps wandered: in clinic, we'd recheck those.

- **Barnaby:** No hearing aids? I got my bees back for free?
- **Hoot:** Free! If it hadn't come back with the wax out, the doctor would look deeper.
- **Hoot:** Some ears just make lots of wax. Your doctor can check it now and then.
- *(patient: cheer)*
- **Barnaby:** Bzzz-rilliant! No more cotton buds. Come on, Gerald: let's go and listen to the hive.

### The Daily Decibel
- S: **WAX PLUG EVICTED; BEEKEEPER HEARS HIVE AGAIN, WALLET UNOPENED** A plug in view, a flat tymp with a tiny canal volume, normal bone, and a retest that proved it.
- A: **BARNABY UNPLUGGED! FORTY THOUSAND GERALDS REJOICE** Bone normal, air blocked: wax out, hearing back, no hearing aids.
- B: **WAX OUT, BEES BACK, OWL SMUG** The gap showed up; a few stamps wandered.
- C: **SOME BEEPS GOT STUCK IN THE WAX, CONFIRMS OWL** Check the bone before blaming the inner ear.
- Do-over: **BARNABY BACK WITH HIS JAR; TRAINEE BACK IN THE BOOTH** Flat tymp plus a tiny canal volume: look for a blockage.
- First stamp FIT (S to C): **TRAINEE TRIES TO FIT HEARING AID INTO WAX PLUG; OWL FAINTS** No aid works through a plug: wax out first, then test again.
- First stamp DOCTOR TODAY (S to C): **WAX PLUG RUSHED TO THE DOCTOR SAME DAY; DOCTOR POLITELY PUZZLED** The wax explained the sudden block and his bone was normal: soon, not today.

## Skye Tailwind's Case (`fluid`)

**The call:** REFER

### Intro
- **Skye:** Ding-dong! Good morning, this is Skye, your senior cabin crew. Please return your owl to the upright position.
- *(Hoot: wing up)*
- **Hoot:** Upright and ready! Welcome aboard, Skye. What's the trouble?
- *(patient: confused)*
- **Skye:** My left ear's been underwater for weeks. A passenger asked for chicken or pasta. I heard 'kitchen or pastor'.
- **Skye:** I fly long-haul on Friday! Can you just pop a hearing aid in and wave me off?
- *(Hoot: gasp)*
- **Hoot:** Hold the trolley! Let's find out what's in that ear first.

Always on the notes: *Left ear muffled, 'underwater', for weeks*; *Flies long-haul on Friday*

### History (pick one per round)

| Question | Pts | Answer | Clue card | Hoot |
|---|---|---|---|---|
| R1: Did it start with a cold? | 2 | Three weeks ago, a real stinker, and I flew with it. The cold left. The blocked ear stayed. | Blocked since a cold and a flight, 3 weeks | A cold plus a landing is hard on the little tube that evens out ear pressure. |
| R1: Does it crackle or pop? | 1 | Crackles when I swallow, like bubble wrap. But it never quite pops. | Crackles when she swallows; never pops |  |
| R1: Peanuts or pretzels? | 0 | Pretzels. Always pretzels. I keep a stash in my apron. Want one, owl? |  | Smooth flying, but not a clue. Ask about her ear! |
| R2: Any pain, drainage, dizziness, or sudden change? | 2 | An ache with the cold, gone now. No drips, no spins. It crept in as the cold cleared. | No pain now, no drainage or dizziness |  |
| R2: Have you had ear trouble before? | 1 | As a kid! I had tiny tubes in my eardrums. Nothing since. | Ear tubes as a child; nothing since | Middle-ear trouble as a kid. Worth telling the doctor! |
| R2: Can you do the safety demo? | 0 | Exits here, here and here. In the event of a water landing... my left ear got there first. |  | Smooth flying, but not a clue. Ask about her ear! |

Red-flag sweep (if skipped): **Hoot:** Always check the red flags: pain, drainage, dizziness, sudden or fluctuating change, one ear only. **Skye:** An ache with the cold, gone now. No drips, no spins. It crept in as the cold cleared.

Red-flag card: *One ear only: YES. Pain, drainage, dizziness, sudden: none. / See a doctor. How soon? You decide.*

- **Skye:** Watch, I'll just pop it. Hnnnngh!
- *(patient: straining)*
- **Skye:** ...Nope. Still underwater.
- **Hoot:** Gently! Forcing it can hurt. Let's look inside instead.

### Otoscopy
First caption: *Fresh speculum. Skye's RIGHT ear first: a clear canal, a healthy eardrum.*

Caption: *Skye's LEFT ear: an average-sized canal, no wax... and a dull, amber eardrum.* (view: fluid)

- **Hoot:** No wax. But the drum is dull and amber, with bubbles behind it. No cone of light.
- **Skye:** Bubbles? Like the fizzy water in first class?
- **Hoot:** Something like that. Let's see if the tymp agrees.
- Card: *Left eardrum dull and amber, with bubbles*

### Tympanometer
Tip: medium (average-sized canal). Right: type A, peak -15 daPa, 0.7 mL, canal 1.2 mL. Left: type B, flat, canal 1.1 mL: reads fluid.

Question: **Skye says it just needs a good pop. What does the tymp say?**
- (right) Fluid behind the drum: it can't move.
- Just pressure: a peak moved left.: Hoot: That would be type C: a peak moved left. Hers has no peak at all.
- A wax plug blocking the probe.: Hoot: A plug makes the canal volume tiny. Hers is a normal 1.1, like her right.

- **Hoot:** Flat, but a normal canal volume: the probe reaches the drum. It just won't move.

### Instructions
- **Hoot:** This morning's listening check: every beep clean, the button works. Dials stay out of view.
- **Hoot:** Tell her: press for every beep, even faint ones. Not for the crackles!
- **Skye:** Beeps only. Cabin crew, prepare for hearing test!

### Test plan
- Right AC (Hoot's montage): "Better ear first. Hoot's montage on the right: fasten your seatbelts!"
- Left AC (player for 2 stamps, then Hoot): "Left ear's yours: the underwater side. Start at 1k."
- Right BC (Hoot's montage): "Hoot's montage: bone on her good right ear!"
  - before:
    - **Hoot:** Bone mostly skips the middle ear. Better ear first: the buzzer goes on her right.
- Then masked bone and masked air wherever the rules ask (Hoot). When masked bone ran and no ear needed masked air: **Hoot:** At these levels, air tones can't cross the head. Only bone needed masking today!

After the tests (said when every ear with bone agrees with the case; otherwise **Hoot:** Bone's in. Let's lay it over the air and see what it says.):

- **Hoot:** Masked bone's in. Let's see where her left ear's marks landed.

### The chart, the shape question, the reveal
- **Hoot:** Here's Skye's chart. Look at her left ear's bone, then its air.
- **Question:** Where is Skye's sound getting stuck?
  - Outer ear: the canal.: Hoot: No wax, and a normal canal volume. Look behind the eardrum.
  - (right) Middle ear: behind the eardrum.
  - Inner ear: the cochlea.: Hoot: Then bone would be down too. Her masked bone is near normal.
- *(the gap comes alive, with the fluid in the gap: BONE FINE, AIR BUBBLING)*
- **Hoot:** Bone near normal, air about 25 dB worse: an air-bone gap, full of bubbles.
- **Skye:** So my ear's a fish tank?
- **Hoot:** A tiny one. The tymp and the drum point to fluid behind it.
- **Hoot:** Middle ear: the canal is clear, the tymp is flat, and bone is fine.

Cards from the chart: *Left: bone normal, air down: a gap* (only when the chart reads conductive); *Left ear only: a clear difference* (red card) (if the ears differ); *Gap of 15+ dB at 500, 1k and 2k* (red card) (only with a gap of 15+ at 500, 1k and 2k)

If the chart and the truth disagree on any of those: **Hoot:** Some stamps wandered, so the chart and the story disagree. In clinic, recheck first!

### The call
- **FIT**: No hearing aids for a puddle! A doctor first: it often clears.
- **REFER** (right): Fluid behind one eardrum in a grown-up: a doctor this week, before Friday's flight.
- **DOCTOR TODAY**: Bone's normal: middle ear, not inner ear. Soon, not today.

**Present the evidence: what shows the trouble is in the middle ear?**
- Proof cards (tags): tymp_fluid, amber_drum, gap. Right: Exactly! It's the middle ear: a doctor this week, before she flies. Not today.
  - tymp_fluid: Yes! Flat with a normal volume: fluid behind the drum. With normal bone: soon, not today.
  - amber_drum: Yes! You can almost see the fluid. With normal bone: a doctor this week, not today.
  - gap: Yes! Bone normal, air down, and a clear canal: it's stuck behind the drum. Soon, not today.
- Wrong card (default): True, but that doesn't show where the trouble is. Look again!
  - flies_friday: That's HER deadline, not a medical emergency. What shows it's the middle ear?
  - after_cold: Careful: a cold can come before an inner-ear loss too. What shows it's the middle ear?
  - abg_flag: That gap sends her to a doctor. Mixed losses have gaps too. What points at the middle ear?
  - left_only: One ear sends her to a doctor. What shows it's the middle ear?
  - red_flag_check: Good news, but not the proof. What shows where the trouble is?
  - left_underwater: That's what she feels. What shows where it's coming from?
  - crackle: A hint, not proof. Which test shows it's the middle ear?
  - tubes_as_kid: Worth telling the doctor. Which test shows it's the middle ear today?

### Payoff
- *(plane)*
- **Hoot:** Referral cleared for take-off: an ear doctor this week.
- **Hoot:** In grown-ups, fluid on one side gets a doctor's look, back of the nose too.
- **Hoot:** It often clears by itself. If not, the doctor has ways to drain it.
- **Skye:** And Friday's flight?
- **Hoot:** Ask the doctor before you fly. Landing with a blocked ear can really hurt.
- **Hoot:** Pain, fever, drips, dizziness, or hearing getting worse? See a doctor that day.
- **Hoot:** Once it clears, we retest. Still down then? Back to the doctor first.
- *(patient: cheer)*
- **Skye:** Ding-dong! Cabin crew, doors to doctor. Thank you for flying Booth Camp!

### The Daily Decibel
- S: **FLUID SPOTTED BEFORE TAKEOFF; OWL AWARDS TRAINEE PILOT WINGS** Amber drum, flat tymp with a normal canal volume, normal bone: middle ear. A doctor this week.
- A: **SKYE SENT TO DOCTOR BEFORE FRIDAY FLIGHT; PRETZELS FOR EVERYONE** Bone normal and a flat tymp: a doctor this week, not today.
- B: **MIDDLE EAR CHECKED IN; TRAINEE STOWS TRAY TABLE** The gap showed up; a few stamps hit turbulence.
- C: **SOME BEEPS LOST IN TURBULENCE, CONFIRMS OWL** A flat tymp with a normal canal volume points behind the eardrum.
- Do-over: **FLIGHT DELAYED: TRAINEE REQUESTS A SECOND BOARDING** Check the canal volume: tiny means blocked, normal means behind the drum.
- First stamp FIT (S to C): **TRAINEE OFFERS HEARING AID TO A FISH TANK; OWL DECLINES** Fluid behind the eardrum: a doctor first, and it often clears.
- First stamp DOCTOR TODAY (S to C): **PRETZEL EMERGENCY DECLARED; DOCTOR SAYS THIS WEEK IS FINE** Normal bone meant the middle ear: a doctor soon, before the flight, not today.

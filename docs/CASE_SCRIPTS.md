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
Caption: *Rocco's RIGHT ear: a roomy canal, shiny eardrum.*

- **Hoot:** Roomy canals, healthy eardrums. No drumsticks stuck in there either.
- **Rocco:** You'd be surprised what ends up in a drummer's ear.
- Card: *Canals clear, eardrums normal*

### Tympanometer
Tip: large (roomy canal). Right: type A, peak -15 daPa, 0.9 mL, canal 1.5 mL. Left: type A, peak -10 daPa, 0.8 mL, canal 1.6 mL.

Question: **What type is it?** (A / B / C, shuffled)

- **Hoot:** Type A both sides: no fluid, no blockage. The bone test will tell us if it's deeper.

### Instructions
- **Hoot:** Tell him: press for every beep, even faint ones. Not for the cymbal in his head!
- **Rocco:** Beeps yes, ringing no. Got it, boss.

### Test plan
- Right AC (player for 6 stamps, then Hoot): "Right ear's yours, up to 8k. Watch what happens between 4k and 8k!"
- Left AC (Hoot at x8): "Left ear at Hoot speed. Same pattern?"
- Right BC (Hoot at x8): "Bone check at Hoot speed: middle ear or inner ear?"
  - before: **Hoot:** Now the bone buzzer, on his right: is it the middle ear, or deeper?
- Then masked bone and masked air wherever the rules ask (Hoot).
- **Hoot:** Unmasked bone matches both ears' air: no gap on either side.

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

Cards from the chart: *Dip at 4k, better at 8k (noise notch)*; *Both ears match (within 5 dB)* (if symmetric); *Bone matches air: no gap*

### The call
- **FIT** (right): No red flags, and he misses words in noisy pubs: hearing aids help. Earplugs every gig!
- **REFER**: Careful is good! But no red flags: ears match, no pain, no spins, nothing sudden.
- **DOCTOR TODAY**: Nothing sudden: it crept up over thirty years of drumming. Not an emergency.

Present the evidence: **Present the evidence: why is it safe to fit Rocco today?**
- Proof cards (tags): no_red_flags, symmetric, both_ears. Right: Exactly! Nothing on the red-flag list, and ears that match: fitting is the right call.
- Wrong card (default): True, but it doesn't prove he's safe to fit. Look for the red-flag check!
  - noise_years: That's why he has a loss, not why it's safe to fit. Find the red-flag check!
  - noise_trouble: That's why he WANTS hearing aids. What shows it's safe to fit them?
  - notch: That's the pattern, not the safety check. Find the red-flag check!
  - ear_clear: True, the exam looks clean. Which clue clears pain, dizziness and sudden change?
  - tymp_a: True, the exam looks clean. Which clue clears pain, dizziness and sudden change?
  - snhl: True, the exam looks clean. Which clue clears pain, dizziness and sudden change?

### Payoff
- **Hoot:** Hearing aids tuned for the high pitches. They often make the ringing less noticeable, too.
- *(hearing aids)*
- *(patient: cheer)*
- **Rocco:** Whoa. I can hear the hi-hat AND my bandmates' terrible jokes!
- **Hoot:** Now protect what's left: earplugs at every gig AND every rehearsal.
- **Choice:** Which earplugs for a drummer?
  - Cotton wool (0 pts): Hoot: Cotton wool? It barely blocks a thing, and it just fell in the snare.
  - Foam earplugs (1 pts): Hoot: Foam works, but it muffles the highs. A drummer wants it even.
  - Musicians' earplugs (2 pts): Hoot: Flat, even quieting: the cymbals still sound like cymbals. Rock on, safely!
- **Hoot:** On stage: hearing aids out, earplugs in. And a hearing check every year.
- **Rocco:** Earplugs in. Ba-dum-TSS!

### The Daily Decibel
- S: **DRUMMER'S NOTCH NAILED; OWL PRESCRIBES EARPLUGS** A textbook notch at 4k and a perfect call. The Decibelles buy musicians' earplugs in bulk.
- A: **ROCCO HEARS HI-HAT AGAIN; PUB DEMANDS QUIETER SOLOS** No red flags and a real need: fit, then protect what's left.
- B: **NOTCH FOUND, DRUMMER FITTED, CYMBALS ON NOTICE** The notch showed up; a few stamps wandered. Hoot recommends practice.
- C: **SOME BEEPS DROPPED THE BEAT, CONFIRMS OWL** Look for the dip at 4k and the comeback at 8k.
- Do-over: **ROCCO BACK FOR AN ENCORE; BRINGS DRUMSTICKS** Noise notches hide between 3k and 6k. Rocco will be back next Friday.

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
| R2: Any pain, drainage, dizziness, or sudden change? | 2 | No pain, no drips. But the room SPINS: two or three hours at a time, four times since spring. / Last one ten days ago. Steady today, and no sudden drop this week. | Room-spinning spells for hours |  |
| R2: Have you had a cold or a blocked nose lately? | 1 | Not a sniffle all year. Sea air! | No cold or blocked nose | Good: a cold can clog the middle ear and muffle hearing for a while. |
| R2: What's the best sea shanty? | 0 | Anything with a chorus. Ten verses minimum. |  | Shipshape answer, but not a clue. Ask about her ears! |

Red-flag sweep (if skipped): **Hoot:** Always check the red flags: pain, drainage, dizziness, sudden change. Any of those? **Marina:** No pain, no drips. But the room SPINS: two or three hours at a time, four times since spring. / Last one ten days ago. Steady today, and no sudden drop this week.

Red-flag card: *Dizziness: YES, spinning spells. / One ear only: YES = see a doctor.*
; extra card: *Last spell 10 days ago; no sudden drop in 3 days*

- **Marina:** Oh! I brought my hearing test from my spring sea medical. It's on file.
- **Hoot:** Brilliant! Old results are gold. We'll compare them with today's.

### Otoscopy
Caption: *Marina's LEFT ear: an average-sized canal, shiny eardrum.*

- **Hoot:** Clear canals, healthy eardrums. No seawater, no barnacles.
- **Marina:** Barnacles! You laugh, but I've seen things.
- Card: *Canals clear, eardrums normal*

### Tympanometer
Tip: medium (average-sized canal). Right: type A, peak 0 daPa, 0.7 mL, canal 1.2 mL. Left: type A, peak -15 daPa, 0.6 mL, canal 1.1 mL.

Question: **Her ear feels full. Is it fluid behind the eardrum?**
- (right) No: type A, a normal peak. No fluid.
- Yes: it's flat, type B.: Hoot: A flat B would mean fluid. Hers has a normal peak.
- Yes: type C, negative pressure.: Hoot: Her peaks sit near zero. A type C sits far to the left.

- **Hoot:** No fluid behind that drum. The bone test will tell us where the fullness lives.

### Instructions
- **Hoot:** Tell her: press for every beep, even faint ones. Not for the roar!
- **Marina:** Beeps yes, engine room no. Aye aye!

### Test plan
- Right AC (Hoot at x8): "Better ear first, like the pros. I'll zip through the right!"
- Left AC (player for 8 stamps, then Hoot): "Left ear's all yours. Keep an eye on the low pitches!"
- Left BC (Hoot at x8): "Bone check at Hoot speed: middle ear or inner ear?"
  - before: **Hoot:** Now the bone buzzer, on her left. Watch out for the Ghost!
- Then masked bone and masked air wherever the rules ask (Hoot).
- **Hoot:** Masked bone sits with the air: no gap. Not the middle ear.

### The chart, the shape question, the reveal
- **Hoot:** Today's chart, with her spring test dashed. What does her left ear show?
- **Question:** What does Marina's left ear show?
  - (right) Rising: worst in the LOW pitches.
  - A noise notch at 4k.: Hoot: No dip at 4k: her high pitches are nearly fine.
  - A ski slope: worst in the high pitches.: Hoot: Look left on the chart: the low pitches are the worst.
- *(the rising comes alive: LOW PITCHES DOWN)*
- **Hoot:** Low pitches about 25 dB worse than spring, and she has good days: hearing that comes and goes.
- **Marina:** So my ear has tides?
- **Hoot:** Something like tides. An ear doctor can find out why.
- **Hoot:** A low-pitch loss in one ear, worse than in spring.

Cards from the chart: *Left ear only* (if asymmetric); *Hearing comes and goes*; *Low pitches 25 dB worse than in spring*; *Bone matches air: no gap*

### The call
- **FIT**: Drop anchor! Dizziness is a red flag. Doctor first; hearing aids may help later, between spells.
- **REFER** (right): Spins, a full roaring ear, hearing with tides: set course for the ear doctor!
- **DOCTOR TODAY**: Spells for months, none today, no sudden drop in three days. Soon, not today.

Present the evidence: **Present the evidence: why does Marina need a doctor first?**
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
- **Hoot:** Hearing suddenly worse? Doctor that day. Weakness, numbness, double vision or slurred speech? Emergency!
- **Marina:** Aye. And then maybe something for the hearing?
- **Hoot:** Exactly. Hearing aids can help between spells, once the doctor has had a look.
- *(patient: cheer)*
- **Marina:** Aye aye. My first mate takes the wheel till the doctor clears me.

### The Daily Decibel
- S: **CAPTAIN'S SPINNING SPELLS SPOTTED; OWL SALUTES SHARP TRAINEE** A rising loss, a spring comparison and a perfect call. The ferry runs on time.
- A: **FERRY CAPTAIN STEERED TO EAR DOCTOR; LOW TIDE IN LEFT EAR** Dizziness plus a one-sided, changing loss: a doctor looks first.
- B: **MARINA REFERRED; TRAINEE FINDS SEA LEGS** The rising pattern showed; a few stamps drifted.
- C: **SOME BEEPS LOST AT SEA, CONFIRMS OWL** Watch the low pitches, and compare with old results.
- Do-over: **MARINA BACK TOMORROW, FIRST MATE AT THE WHEEL; BRINGS FISH PIE** Spinning plus one ear: always a doctor first.

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

Red-flag sweep (if skipped): **Hoot:** Always ask about red flags: pain, drainage, dizziness. **Dash:** No pain, no drips. A bit wobbly yesterday, fine now. Just the whoosh.

Red-flag card: *Sudden, one ear, yesterday: YES. Dizzy too. / See a doctor. How soon? You decide.*
; extra card: *Wobbly yesterday: dizziness*

- **Hoot:** Any face droop, numbness, slurred speech or double vision? Those mean the ER now.
- **Dash:** None of that. Just the ear.
- **Hoot:** A sudden loss in one ear, yesterday. Quick AND careful: let's look.

### Otoscopy
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
- A tymp can't tell.: Hoot: It can! A wax plug flattens the curve and shrinks the canal volume.

- **Hoot:** Type A both sides: no fluid, no wax plug. The bone test shows if it's deeper.

### Instructions
- **Hoot:** Tell him: press for every beep, even faint ones. No racing the beeps!
- **Dash:** Beeps only. Fast but accurate. Like my deliveries!

### Test plan
- Left AC (Hoot at x8): "Better ear first, like the pros. Left at Hoot speed!"
- Right AC (player for 3 stamps, then Hoot): "Right ear's yours. Start at 1k, as always."
- Right BC (Hoot at x8): "Bone check at Hoot speed: where is the trouble?"
  - before: **Hoot:** Wax would block air but not bone. The bone buzzer will tell us!
- Then masked bone and masked air wherever the rules ask (Hoot).
- **Hoot:** Masked bone is in. Let's see where it landed.

### The chart, the shape question, the reveal
- **Hoot:** One ear down overnight. Now: where did the masked bone land?
- **Question:** What type of loss is Dash's right ear?
  - (right) Sensorineural: bone is down with the air.
  - Conductive: blocked, like wax.: Hoot: Then bone would be near normal. His masked bone is down with the air.
  - Mixed: a bit of both.: Hoot: Mixed needs a gap too. His bone and air sit together.
  - (graded against the measured type of the right ear)
- *(the flat_one comes alive: ONE EAR, OVERNIGHT)*
- **Hoot:** Right ear needs 40 to 60 dB, left ear normal. One ear, overnight.
- **Dash:** So it's not wax?
- **Hoot:** Not wax, not fluid: bone is down too. That's what makes it urgent.
- **Hoot:** Sooner is better. Doctors still treat after three days, but today beats tomorrow.
- **Hoot:** Sensorineural and sudden: the inner ear or nerve changed overnight.

Cards from the chart: *Right ear down, bone too: inner ear or nerve*; *Left ear normal*

### The call
- **FIT**: Hold the pizza! A brand-new sudden loss needs a doctor first, and today.
- **REFER**: A routine referral could take weeks. A sudden loss can't wait: TODAY.
- **DOCTOR TODAY** (right): Hot delivery! Sudden sensorineural loss is urgent: treatment works best early. Doctor TODAY!

Present the evidence: **Present the evidence: why TODAY and not next month?**
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
- *(patient: cheer)*
- **Dash:** Same day? Faster than my pizzas! Thanks, owl!

### The Daily Decibel
- S: **SUDDEN LOSS SPOTTED IN RECORD TIME; PIZZA STILL HOT** One ear, overnight, bone down too: a same-day referral. Sooner was better.
- A: **PIZZA BOSS RUSHED TO EAR DOCTOR SAME DAY; TOPPINGS DEBATE CONTINUES** A sudden one-sided loss can't wait: doctor today.
- B: **DASH SENT TO DOCTOR TODAY; OWL CHECKS WATCH** The call was right; a few stamps wandered.
- C: **SOME BEEPS ARRIVED COLD, CONFIRMS OWL** Sudden plus sensorineural means doctor today.
- Do-over: **TRAINEE DEMANDS REMATCH; DASH ALREADY AT THE DOCTOR** Remember: sudden hearing loss is urgent, even after three days. Dash made his appointment anyway.

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
Caption: *Ginger's RIGHT ear: a narrow canal, shiny eardrum.*

- **Hoot:** Narrow canals, healthy eardrums. Nothing hiding in there.
- **Chip:** Not even a chocolate chip? I'm insulted.
- Card: *Canals clear, eardrums normal*

### Tympanometer
Tip: small (narrow canal). Right: type A, peak -10 daPa, 0.7 mL, canal 1.0 mL. Left: type A, peak -5 daPa, 0.6 mL, canal 1.0 mL.

Question: **Is her middle ear the problem?**
- (right) No sign of it: type A, both sides.
- Yes: flat, type B. Fluid.: Hoot: A flat B would mean fluid. Hers have normal peaks.
- Yes: type C, negative pressure.: Hoot: Her peaks sit near zero. A type C sits far to the left.

- **Hoot:** Type A both sides: no fluid, no blockage. The bone test decides if it's deeper.

### Instructions
- **Hoot:** Tell her: press for every beep, even faint ones. Chip doesn't get a button.
- **Chip:** Discrimination! I'm calling my agent.
- **Ginger:** Beeps only. Got it.

### Test plan
- Right AC (player for 7 stamps, then Hoot): "Right ear's yours. Watch the middle pitches!"
- Left AC (Hoot at x8): "Left ear at Hoot speed. Same shape?"
- Right BC (Hoot at x8): "Bone check at Hoot speed: middle ear or inner ear?"
  - before: **Hoot:** Now the bone buzzer: middle ear, or deeper?
- Then masked bone and masked air wherever the rules ask (Hoot).
- **Hoot:** Unmasked bone matches BOTH ears' air: no gap on either side.

### The chart, the shape question, the reveal
- **Hoot:** Here's her chart, with the old one dashed. What shape do you see?
- **Question:** What shape is Ginger's hearing loss?
  - (right) A cookie bite: worst in the middle pitches.
  - A ski slope: worst in the high pitches.: Hoot: Look at 4k and 8k: they come back up.
  - A noise notch at 4k.: Hoot: Her dip is wider and at lower pitches: 1k to 2k, not 4k.
- *(the cookie comes alive: COOKIE BITE)*
- **Chip:** Hey, that's MY look!
- **Hoot:** Worse in the middle, better at both ends: a cookie bite! These often run in families.
- **Ginger:** So that's why Chip and I get along.
- **Hoot:** And it matches her chart from nine years ago, within 5 dB. Stable.
- **Hoot:** The middle pitches carry lots of speech, so words drop out of voices.

Cards from the chart: *Worst in the middle pitches (cookie bite)*; *Both ears match (within 5 dB)* (if symmetric); *Bone matches air: no gap*; *Same bite as nine years ago: stable*

### The call
- **FIT** (right): Sweet call! Stable for years, ears match, no red flags: hearing aids tuned for the middle pitches.
- **REFER**: Family history isn't a red flag. Ears match, nothing sudden: fit her, and offer a genetics chat.
- **DOCTOR TODAY**: Since SCHOOL? That's the opposite of sudden! No emergency here.

Present the evidence: **Her dad and grandma have it too. Why is it still safe to fit her?**
- Proof cards (tags): no_red_flags, symmetric, both_ears, stable, stable_chart. Right: Exactly! Stable, matching ears, no red flags: fitting is the right call.
- Wrong card (default): True, but it doesn't show she's safe to fit. Look for the red-flag check!
  - family: That's family history, not a red flag. What shows it's safe?
  - ear_clear: True, the exam looks clean. Which clue clears pain, dizziness and sudden change?
  - tymp_a: True, the exam looks clean. Which clue clears pain, dizziness and sudden change?
  - snhl: True, the exam looks clean. Which clue clears pain, dizziness and sudden change?
  - voices_drop: That's what's wrong, not why it's safe. Look for the red-flag check!
  - cookie: That's what's wrong, not why it's safe. Look for the red-flag check!

### Payoff
- **Hoot:** Hearing aids tuned for the middle pitches: right where her bite is.
- *(hearing aids)*
- *(patient: cheer)*
- **Ginger:** Oh! I can hear the back row. Even the hecklers!
- **Chip:** Where are MY hearing aids?
- **Hoot:** It runs in families: offer a genetic counselling referral. Not a red flag, so no need to wait.
- **Hoot:** And a hearing check every year: some family patterns slowly change.
- **Chip:** Same time next year, owl. Bring snacks.

### The Daily Decibel
- S: **COOKIE BITE CRACKED; PUPPET DEMANDS CREDIT** A textbook cookie bite, stable for nine years, and a perfect call.
- A: **VENTRILOQUIST HEARS THE BACK ROW AGAIN; CHIP STEALS THE SHOW** Stable, matching ears, no red flags: fit, tune for the middle, offer a genetics chat.
- B: **MIDDLE PITCHES FOUND, GINGER FITTED; CHIP UNIMPRESSED** The bite showed up; a few stamps missed their cue.
- C: **SOME BEEPS MISSED THEIR CUE, CONFIRMS OWL** Look for the dip between 1k and 2k.
- Do-over: **GINGER AND CHIP BOOKED FOR AN ENCORE** Cookie bites sit in the middle pitches. Family history alone isn't a red flag.

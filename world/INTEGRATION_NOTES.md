# world/ integration notes (builder B)

The §6.1 API (`walk_in`, `walk_to`, `sit`, `stand`, `focus_camera`, `put_on_earphones`,
`take_off_earphones`, `play_patient_reaction`, `set_world_saturation`, `get_booth_texture`,
`set_booth_view_active`, `get_ear_screen_position`, `get_patient`, `get_main_camera`, `hoot_emote`,
`demo_start`) and the 15 §6.2 reaction kinds are unchanged. v3 (Day 2) adds four reaction kinds and
some Day 2 extras, below.

## Contract change: SHOTS gained two entries

`SHOTS` now ends with `&"title"` (slow drift for the title backdrop) and `&"fitting"` (Gus, Doris and
the desk for the fitting scene). The original eight are unchanged and keep their order.

## Extras (story-only, called by name; nobody else needs them)

| Method | Notes |
|---|---|
| `doris_enter()` (coroutine) | Door bursts open, Doris walks to `DORIS_SPOT`, turns to Gus. |
| `doris_react(kind)` | Same kinds as Gus. Does nothing while Doris is hidden. |
| `gus_look(target)` | `&"hoot"`, `&"doris"`, anything else = camera. Standing, he turns his body too. Doris/camera lock his gaze until `gus_look(&"hoot")`, so Hoot's lines don't turn his head away. |
| `set_title_mode(on)` | Gus waits at `TITLE_GUS_SPOT` with idle reactions; the camera drifts on `&"title"`. |
| `play_birdsong()` | Quiet procedural chirps (Sfx `chirp`, -9 dB) and a confetti burst over Gus's head. |
| `get_head_screen_position()` | Gus's head projected by the main camera. |
| `take_off_glasses()`, `put_on_glasses()`, `put_on_hearing_aids()` | Props. |
| `get_muffle()` | 0 clear .. 1 fully muffled (grey fitting world). Read by `story/voice.gd` through `Stage.clinic`. |

Constants: `SPOT_FACING`, `DORIS_SPOT`, `TITLE_GUS_SPOT`, `GUS_TURN_TO_DORIS`, `GUS_FACE_CAMERA`.

## v3 (Day 2: Bonnie)

**Contract change: `REACTIONS` gained `&"tickle"`, `&"cross_heard"`, `&"overmasked"`, `&"wave"`.**
The clinic plays the AudiOtron's `Events.patient_reaction` kinds itself:

| Kind | What you see |
|---|---|
| `tickle` | Bonnie giggles ("hee!"), shimmies; the oscillator wiggles. |
| `cross_heard` {ear, via, masked} | The **Cross-Hearing Ghost** (`world/characters/ghost.gd`): pops out by the test ear, slips behind the head, says "boo!" at the OTHER ear, dives to her button hand and poofs. A cheeky grin when `masked` (too little noise). One ghost at a time. |
| `overmasked` | Spiral eyes and a wavy mouth, Hoot gasps, a purple noise burst with "shh" puffs. Visual only. |
| `wave` | A friendly wave (arrivals and goodbyes). |

The clinic also listens to `Events.masker_changed` (the first masker-on of each test makes a Ghost
peek out of the masked ear and get shooed: X eyes, "SHOO!", poof), `Events.technique_event`
(`plateau_found` busts a Ghost: "BUSTED!"), `Events.transducer_changed` and tone events (the
oscillator buzzes with rings and a "bzz" label while a bone tone plays; a lamp-like indicator).

Extras for the story (called by name):

| Method | Notes |
|---|---|
| `put_on_bone_oscillator(ear)` | Steel headband over the head, beige oscillator on that mastoid (not touching the ear). |
| `take_off_bone_oscillator()` | Removes the band (and the masking phone). |
| `put_on_masking_phone(ear)` | One blue (left) or red (right) earphone cup on the NON-test ear, labelled L/R. |
| `put_down_basket()` | Bonnie sets her croissant basket on the desk (`sit()` does it too). |
| `give_croissant()` (coroutine) | A croissant hops from the basket to Hoot, who munches it (crumbs). |
| `walk_out()` (coroutine) | Stand if seated, wave, walk out through the waiting-room door, door closes. |
| `patient_name()` | "Gus", "Bonnie", ... (the bean's display name). Lip-sync follows this speaker. |

Bonnie's bean (`world/characters/bean.gd`, `BONNIE`): face style `&"bonnie"` (lashes, freckles, a
flour smudge), hair bun with a wooden spoon, teal reading glasses perched on top of her head (the
running "lost glasses" gag), apron, croissant basket. New face eyes `&"spiral"` (dizzy).

## Notes

- `set_world_saturation(v)` muffles at the sound sources, never with bus effects. Below 1.0 the
  clinic's own sounds play quieter and lower, and `get_muffle()` (0 clear .. 1 grey) lets the story's
  dialogue voice switch to a muffled syllable bank.
- **Engine audio hang (affects everyone, please read).** In headless runs (Dummy audio driver) the
  audio thread sometimes gets stuck spinning inside audio mixing while it holds the AudioServer lock.
  Seen two ways, both confirmed with gdb or the crash handler:
  1. Mid-run: `AudioServer.add_bus_effect()` (my old Master low-pass) blocked forever in
     `pthread_mutex_lock`. That is why the clinic no longer touches bus effects. Please don't add or
     remove bus effects at runtime in other modules either.
  2. At exit: `run_tests.gd` prints its summary, then the main thread waits forever in `pthread_join`
     on the spinning audio thread. Roughly 1 run in 4 to 10 of the full suite, and 1 in 18 even with
     `world/tests` and `story/tests` removed, so it is not caused by those tests. Run the suite under
     `timeout` and treat "summary printed, then timeout" as an engine exit hang, not a test failure.
  The three rendered full autoplay runs all exited cleanly.
- The otoscope sits in a charging cradle on the desk (`room.gd`).
- Tests: `world/tests/test_clinic.gd` (API, every reaction, walk/sit/ear projection with right ear on
  the screen's left, muffle amount with no bus-effect changes, story extras, every SHOTS entry).

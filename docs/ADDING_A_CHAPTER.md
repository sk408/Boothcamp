# Adding a chapter (parallel threads)

Several threads build chapters at once on their own branches and open PRs into `main`.
The main build thread merges every PR. Read `CONTRACTS.md` first; this page only says where new work goes
so branches don't collide.

## Branches

- `main`: released, playable game. Every merge keeps `tools/run_tests.sh` and `tools/autoplay_check.sh` (every day) green.
- One branch per chapter or track: e.g. `chapter-2-bone-conduction`, `chapter-3-speech`, `cases`.
- Rebase on `main` before opening a PR. Keep PRs small: one chapter or one shared change at a time.

## Where a chapter's files live (all new files, owned by that chapter)

| What | Path |
|---|---|
| Design doc (patient truth table, beats, Hoot lines, rules with numbers) | `docs/CHAPTER<N>.md` |
| Patient | `core/patients/<patient_id>.tres` (a `PatientProfile`) |
| Level director scene | `story/level_<chapter_id>.tscn` + `.gd` |
| Chapter-only mini-games and boards | `story/games/<chapter_id>_*.gd` |
| Characters and props | `world/characters/<name>.gd`, `world/props/<name>.gd` |
| Tests | `<module>/tests/test_<chapter_id>_*.gd` (the runner finds them) |
| Dev shot scene | `story/dev_<chapter_id>.tscn` or `ui/dev/dev_<thing>.tscn` |
| **(v4)** Hoot's movie (optional) | `story/explainers/movies/<movie_id>.gd` + one line in `story/explainers/movies.gd` (below) |

### Speech audiometry (SRT, WRS, speech in noise)

- New screen: `ui/speech/` (e.g. `speech_screen.tscn`), API documented in a new `CONTRACTS.md` section on the branch.
  Reuse the AudiOtron look (`Palette`, `UiDraw`, `Juice`) and `Audiogram` for plotting SRT/PTA; don't fork the tone screen.
- Logic: `core/speech/` (session, scoring, a `SpeechRules` static class). Keep speech constants there, not in `ClinicRules`.
- Word lists and sentences: `core/speech/material/*.json`, **original text only** (no NU-6, W-22, CID, AudiTec or
  QuickSIN words or sentences). Recordings, when they exist, go in `assets/speech/<list_id>/<item_id>.wav`
  (uncompressed 8- or 16-bit PCM, WAV only: `docs/SPEECH.md` §7); every item
  must also work as on-screen text so the game plays before any audio is recorded.
- Speech levels follow the same safety path (`AudioSafety`) as tones.

### Patient cases (conditions, fit / refer / see a doctor today)

- One `PatientProfile` per case in `core/patients/`, case data (history answers, otoscopy finding, tymp type,
  red flags, correct decision and why) in `story/cases/<case_id>.json`, and one shared case runner
  `story/level_case.gd` that plays any case from its JSON.
- Conductive cases (Day 10 wax, Day 11 fluid) carry `bc_right` / `bc_left` (the v3 bone-conduction fields from
  chapter 2); otosclerosis stays Bonnie's (Day 2). A deaf ear (Day 12) puts its air past the dial (up to
  `ClinicRules.max_db(f) + 30`): masked tests then store no response.
- Optional case keys pick the look in the ear (`otoscopy.view`: clear, wax, fluid), cards that show only when the
  chart says so (`findings[].when`: symmetric, asymmetric, conductive, abg_flag, shadow, no_response), and a `retest` block that brings the
  patient back after treatment with their own `<id>_after.tres` truth (Day 10). `CONTRACTS.md` §11 lists every key.
- Clinical wording for every case is reviewed by Steve before release.

## Registering the chapter: one `Game.CHAPTERS` entry

```gdscript
{"id": "rocco", "day": 6, "title": "Day 6: Rocco Rimshot", "patient_id": "rocco",
	"teaches": "Case file: ringing ears", "scene": "res://story/level_case.tscn",
	"requires": "bonnie", "face": "Rocco", "tint": Color("#ffd9c7")},
```

- **Every chapter is open from the start and can be played in any order** (Steve's rule). There are no locks:
  `Game.is_chapter_unlocked()` is always true, and there is no "unlock all days" setting any more.
- `requires` is only a hint: the chapter best played first. It picks the **suggested** day
  (`Game.suggested_chapter_id()`: the first day not done whose `requires` is done), which wears a small
  "UP NEXT" badge on the title's day picker and is what Play starts. The Daily Decibel stamps "UP NEXT!" and makes
  "Next: Day N" the big button after a chapter's first clear.
- The title's Days card is a scrolling grid that lays out any number of chapters (columns and visible rows follow
  the screen; it fits 1280x720 and 1920x1080), with keyboard (arrows, Enter, Esc) and mouse (click, wheel) control.
  Each card shows the DAY chip, the part of `title` after the colon, `teaches`, a best grade and a portrait.
- `face` (a `Portraits` speaker id) and `tint` (a `Color` or a `"#rrggbb"` string) are optional. The title's own
  `DAY_FACES` / `DAY_TINTS` tables win when they have the id; otherwise the card uses these keys, else a cream card
  with a star. So a chapter branch never needs to edit `story/title_screen.gd`.
- Keep `title` as `"Day N: Name"` and `day` unique. The bot finds a card by its title (`--via-days --pick=<id>`).

## Hoot's movies: an animated explainer for your chapter (v4)

A chapter may open with a short cartoon that explains its one hard idea before the patient arrives (Day 2:
"Hoot's masking movie", `docs/CHAPTER2.md` §16). Movies are **data**: you write a scene list; the shared player
types the captions, plays the stings and asks the stage to draw each scene. API: `CONTRACTS.md` §3.4. You never
need to edit the shared stage or player: everything below lives in your chapter's own files plus one registry line.

1. **Write the data:** `story/explainers/movies/<movie_id>.gd` (or a file in your chapter's folder):
   ```gdscript
   extends RefCounted
   const MOVIE: Dictionary = {
   	"id": "tymp", "title": "Hoot's tymp movie", "subtitle": "The Wobbly Drum",
   	"chapter": "rocco",            # the Game.CHAPTERS id that plays it and offers the replay
   	"narrator": "Hoot",
   	"seen_at": "drum",             # optional: reaching this scene counts as seen (default: the last scene)
   	"stage": "res://story/rocco/tymp_sets.gd",   # optional: your own sets script (step 3)
   	"scenes": [
   		{"id": "drum", "set": "drum", "title": "The wobbly drum", "duration": 8.0,
   			"captions": ["Meet the eardrum: a tiny drum skin that wobbles with every sound."],
   			"teaches": "The eardrum moves with sound.",       # one idea per scene
   			"board": "What the stage draws and animates (never shown).",
   			"params": {}, "cues": [{"t": 0.4, "sfx": "pop", "vol_db": -8.0}]},
   	],
   }
   ```
   Rules: captions are Hoot lines, **18 words or fewer**; one idea per scene; the whole movie **about 60-100 s**
   (`Movies.validate()` allows 45-110); cues are `Sfx` names (`CONTRACTS.md` §2.4) at **-6 dB or softer**
   (the player caps them); anything loud ("too loud", noise, overmasking) is **drawn, never played**. Facts and
   numbers come from `ClinicRules` and are reviewed by Steve; the test should check them against the rules.
   A one-card **recap** for later in the day is a movie too: `"short": true` (5-30 s), never listed for replay
   (Day 2's `masking_recap.gd`).
2. **Register it:** one line in `story/explainers/movies.gd` `MOVIES` (`"tymp": "res://story/explainers/movies/tymp.gd"`).
3. **Pick the sets: built-in, the no-code card, or your own sets script.**
   - **Built-in sets** (`explainer_stage.gd` `SETS`): the ten masking sets (`meet`, `air`, `wall`, `bone`, `ghost`,
     `mask`, `under`, `over`, `plateau`, `outro`), drawn from their `params` (`docs/CHAPTER2.md` §16). Reuse them when
     the idea fits (a head, two cochleas, a cup, the buzzer, the shhh cloud).
   - **No code:** `"set": "card"` draws a chunky title card from data alone: `"params": {"heading": "The Wobbly Drum",
     "lines": ["Sound pushes the drum in.", "It wobbles back out."], "icon": "note", "tint": "#e9f4ff"}`. At most
     4 lines of 36 characters (`Movies.validate()` checks); they pop in one by one (`line_at: [s]` to time them).
     Icons: `""`, `"snails"`, `"ghost"`, `"cloud"`, `"note"`, `"dial"`, `"hoot"`; `"hoot": false` hides the waving
     Hoot. A `set` nobody knows also falls back to a card with the scene's `title`, so a new movie plays (as cards)
     before its art exists (`Movies.validate(id, Stage2D.SETS)` still lists the unknown set, so the art is not
     forgotten).
   - **Your own sets script** (your chapter's files, no shared edit): point `MOVIE.stage` at a script like
     ```gdscript
     extends "res://story/explainers/explainer_sets.gd"
     const SETS: Array[StringName] = [&"drum"]

     func _set_drum() -> void:   # a pure function of t: no tweens, nodes or RNG
     	var wob := sin(t * 9.0) * 12.0 * _k(1.0, 2.0)   # starts wobbling between 1 and 2 s
     	s._circ(Vector2(440, 250) + Vector2(wob, 0), 70.0, Stage2D.SKULL)   # the eardrum, chunky ink outline
     	s._chip(String(params.get("word", "wobble!")), Vector2(440, 80), Stage2D.GOLD, 26, Stage2D.INK, _pop(0.5))
     ```
     The stage hands every set it does not know to this script, inside its own `_draw()`: you get the same `t`,
     `duration`, `params`, `scene_id` and `scene_title` as a built-in set; `s` is the stage (all its helpers:
     `s._snail()`, `s._cloud()`, `s._note()`, `s._text()`, `s._chip()`, `s._push()` / `s._pop_xf()`, `s.draw_*()`),
     `Stage2D.<COLOR>` its palette (`INK`, `NOISE`, `GOLD`, `SKULL`...), and `_k()`, `_pop()`, `_ring()` are on the
     base. `Movies.validate(id, Stage2D.SETS)` accepts your SETS and reports a missing script or a missing
     `_set_<id>()`. A working example: `tests/fixtures/fake_movie.gd` + `tests/fixtures/fake_movie_sets.gd`.
   - Give each scene a short `"title"` (the numbered chip in the stage's corner).
   - Check it with
     `timeout 400 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 -- --scene=res://story/explainers/dev_explainer.tscn --shots=/abs/dir --movie=tymp --speed=2`
     (one shot per scene, `explainer_tymp_<NN>_<scene>`; `--at=0.2,0.6,0.95` shoots several moments, `--from=drum
     --only` one scene, `--reduced-motion` with that setting on, `--extra-movie=res://...gd` for a movie file you
     have not registered yet), and LOOK at every shot.
4. **Play it from your level** (copy `level_bonnie._movie()`): emit phase `explainer` {movie, source, seen}, then
   instance `res://story/explainers/explainer_player.tscn`, `await player.call("play", id, "day_start")`, free it.
   Once `Game.is_movie_seen(id)` is true, offer it with a choice (best = skip) instead of playing it again. If the
   result says `skipped`, have Hoot say where it lives (pause menu, "Watch <title>"). A recap mid-day: copy
   `level_bonnie._recap()`. The player emits the `explainer` beat (solver = skip), so the autoplay bot and
   `--mouse` need no edits.
5. **Replay is free:** the pause menu offers every movie whose `chapter` is the current chapter (one: a "Watch
   <title>" button; two or more: a "Hoot's Movies..." vertical list with the day, title and length per row), and
   every movie on the title's Options and its "Hoot's Movies" button. Recaps (`"short": true`) are never listed.
   Nothing to add; check the list with `dev_explainer --list`.
6. **Test it:** add your movie to a test like `tests/test_contracts_v4.gd` (`Movies.validate(id, Stage2D.SETS)` is
   empty, the scene ids, the facts against `ClinicRules`).

The player's controls are the same for every movie: Space / Enter / a click advance like the dialogue box (finish
the caption, then the scene's next caption, then the next scene), Esc = skip the movie, P = pause; buttons "Next"
(the last scene: "Start the day" / "Done"), "Skip movie" and "II" (pause). The music is ducked while it plays.

## Shared files: additive changes only

`autoload/events.gd`, `autoload/game.gd`, `autoload/clinic_rules.gd`, `core/patient_profile.gd`, `core/patient_sim.gd`,
`project.godot` (InputMap) and `CONTRACTS.md` are shared. On a chapter branch you may only **add**:

- new signals at the end of `events.gd`, in a block headed `# --- <chapter_id> ---`;
- one entry in `Game.CHAPTERS` (and `SHOP_ITEMS` if needed) plus new medal / phase ids;
- new `PatientProfile` fields **with defaults that keep every existing patient behaving exactly as before**;
- new input actions (never rebind existing ones);
- new beat ids for `Events.awaiting_input` (the emitter supplies the solver, so the autoplay bot needs no edits);
- a new `CONTRACTS.md` section marked with the chapter id.

Don't edit or reorder existing lines in those files. If you need an existing API to change, write the request in
`res://<module>/INTEGRATION_NOTES.md` on your branch and say so in the PR; the main build thread decides and
makes the change on `main`.

## Before opening a PR

1. `godot --headless --path . --import`, then `tools/run_tests.sh` (all green, incl. `test_vendor_free`).
2. `tools/autoplay_check.sh` for **every** day (`--day=N`), keyboard and `--mouse`, and once from the day picker
   (`--via-days --pick=<id>`, add `--mouse` to scroll and click the card like a player).
3. A few rendered screenshots of the new chapter (`tools/shots.sh`) attached to the PR.
4. The PR description lists every shared-file addition.
5. Any new data file the game reads at run time that is not a Godot resource (patient or case JSON, word
   lists, movie data in JSON) is added to the `include_filter` of BOTH presets in `export_presets.cfg`,
   "Windows Desktop" and "Web", or the exported game silently runs without it. Every push to main
   redeploys the web build to GitHub Pages (`.github/workflows/pages.yml`), so a missing filter shows up
   there first.

No vendor names, logos, art, word lists or recordings anywhere in the repo.

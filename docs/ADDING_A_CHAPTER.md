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
  QuickSIN words or sentences). Recordings, when they exist, go in `assets/speech/<list_id>/<item_id>.ogg`; every item
  must also work as on-screen text so the game plays before any audio is recorded.
- Speech levels follow the same safety path (`AudioSafety`) as tones.

### Patient cases (conditions, fit / refer / see a doctor today)

- One `PatientProfile` per case in `core/patients/`, case data (history answers, otoscopy finding, tymp type,
  red flags, correct decision and why) in `story/cases/<case_id>.json`, and one shared case runner
  `story/level_case.gd` that plays any case from its JSON.
- Conductive cases (wax, fluid, otosclerosis-like) use the v3 bone-conduction fields from chapter 2.
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
types the captions, plays the stings and asks the stage to draw each scene. API: `CONTRACTS.md` §3.4.

1. **Write the data:** `story/explainers/movies/<movie_id>.gd`:
   ```gdscript
   extends RefCounted
   const MOVIE: Dictionary = {
   	"id": "tymp", "title": "Hoot's tymp movie", "subtitle": "The Wobbly Drum",
   	"chapter": "rocco",            # the Game.CHAPTERS id that plays it and offers the replay
   	"narrator": "Hoot",
   	"scenes": [
   		{"id": "drum", "set": "drum", "duration": 8.0,
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
2. **Register it:** one line in `story/explainers/movies.gd` `MOVIES` (`"tymp": "res://story/explainers/movies/tymp.gd"`).
3. **Draw the sets, or use the card set (no code).**
   - **No code:** `"set": "card"` draws a chunky title card from data alone: `"params": {"heading": "The Wobbly Drum",
     "lines": ["Sound pushes the drum in.", "It wobbles back out."], "icon": "note", "tint": "#e9f4ff"}`. At most
     4 lines of 36 characters (`Movies.validate()` checks); they pop in one by one (`line_at: [s]` to time them).
     Icons: `""`, `"snails"`, `"ghost"`, `"cloud"`, `"note"`, `"dial"`, `"hoot"`; `"hoot": false` hides the waving
     Hoot. A `set` the stage does not know also falls back to a card with the scene's `title`, so a new movie
     plays (as cards) before its art exists (`Movies.validate(id, Stage.SETS)` still lists the unknown set, so the
     art is not forgotten).
   - **Your own art:** add the `set` id to `SETS` in `story/explainers/explainer_stage.gd` and a `_set_<id>()` draw
     function that animates over `t` / `duration` with `params` (a pure function of `t`: no tweens, nodes or RNG;
     use `_k()`, `_pop()`, `_ring()` and the drawing helpers). Reuse the masking sets' props when you can.
   - Give each scene a short `"title"` (the numbered chip in the stage's corner).
   - Check it with
     `timeout 400 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --audio-driver Dummy --fixed-fps 30 -- --scene=res://story/explainers/dev_explainer.tscn --shots=/abs/dir --movie=tymp --speed=2`
     (one shot per scene, `explainer_tymp_<NN>_<scene>`; `--at=0.2,0.6,0.95` shoots several moments, `--from=drum
     --only` one scene, `--reduced-motion` with that setting on), and LOOK at every shot.
4. **Play it from your level** (copy `level_bonnie._movie()`): emit phase `explainer` {movie, source, seen}, then
   instance `res://story/explainers/explainer_player.tscn`, `await player.call("play", id, "day_start")`, free it.
   Once `Game.is_movie_seen(id)` is true, offer it with a choice (best = skip) instead of playing it again.
   The player emits the `explainer` beat (solver = skip), so the autoplay bot and `--mouse` need no edits.
5. **Replay is free:** the pause menu shows "Watch <title>" for every movie whose `chapter` is the current chapter,
   and every movie on the title's Options; the title's "Hoot's Movies" button opens them too. Nothing to add.
6. **Test it:** add your movie to a test like `tests/test_contracts_v4.gd` (`Movies.validate(id, Stage.SETS)` is
   empty, the scene ids, the facts against `ClinicRules`).

The player's controls are the same for every movie: Space / Enter / a click = next scene, Esc = skip the movie,
buttons "Next scene" and "Skip movie"; P pauses.

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

No vendor names, logos, art, word lists or recordings anywhere in the repo.

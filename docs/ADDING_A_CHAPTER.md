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

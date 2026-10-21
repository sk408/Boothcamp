# Integration notes: Days 4-5 (word lists, the Party Noise Test)

Requests from the Days 4-5 branch for the main thread, which owns `tools/autoplay_bot.gd` (the movie branch
rewrote it). Nothing here is applied to the bot by the Days 4-5 builders (`CONTRACTS.md` §9.22, §9.23.1). When a
later Days 4-5 step cannot run `--day=4` / `--day=5` at all without a bot change, it adds the smallest change in
one block marked `# (Days 4-5)` and lists it under "Already in the bot" below.

## Already in the bot

W5a (Day 4) applied the Day 4 part of the patch in `tools/autoplay_bot.gd`, in blocks marked `# (Days 4-5)`. None
of it runs on Days 1-3 or 6-13: each block needs a `wrs` / `sin` test, a word or party sheet, or the `nora` /
`marco` chapter.

- §1: `speech_day` also holds for `nora` and `marco`.
- §3: `_check_wrs_lists(sp, report, problems)` on any day with a `speech.wrs` sheet. It also adds
  `report.wrs_lists` (`ear:list_id:level:mask:pct`, with `:void` on a list that does not count), which only a day
  with word lists prints.
- §5: `_check_nora(res, sp, problems)`. The decision is read from the visit flag `decision`, which is where Day 4
  records it (as the cases do).
- Day 4's movie (M-MV4, not in §9.22): on `nora` the result adds `movies` (the movies that started, as Day 2 and
  the cases print it), and a fresh save (no `--keep-save`) must start `letter_choir`.
- §7: `_speech_shot_key()` and the `wrs` / `sin` shot names. The `_low` / `_descent` shot is now kept for
  `test == &"srt"` only.

P5a (Day 5) applied the rest, in the same kind of blocks. None of it runs before Day 5's chapter or a `sin` sheet:

- §4: `_check_sin_lists(sp, report, problems)` on any day with a `speech.sin` sheet. It also adds `report.sin_lists`
  (`slot:list_id:level:total`, with `:hoot` on a list Hoot scored all of), which only a day with party lists prints.
- §6: `_check_marco(sp, problems)`. The paper's words are read while it is on screen (the `results_continue`
  beat, on `marco` only, before a mouse run clicks it away) and checked for "beeps" and "spondees".
- Day 5's movie (as Day 4's): on `marco` the result adds `movies`, and a fresh save (no `--keep-save`) must start
  `party_noise`.

## The autoplay patch (§9.22)

All of it goes in `_check_speech()` and the two speech shot handlers. Days 1-3 and 6-9 must keep their
`AUTOPLAY_RESULT` lines byte-identical: every new check below runs only when `speech.wrs` or `speech.sin` has a
sheet, or on the `nora` / `marco` chapters.

### 1. Speech days

```gdscript
var speech_day := chapter in ["mike", "nora", "marco"]
```

The generic loop over `srt`, `wrs` and `sin` (every sheet within 10 dB of its `true_db`) stays as it is (D9): WRS
and SIN sheets carry `stored_db` / `true_db` for it. The loop's `words` / `par` columns read 0 for a party sheet;
that is fine.

### 2. Beats

No new bot code. `lens_try`, `call_it`, `flag_pick`, `band_pick`, `plates_serve` and `focus_switch` all carry a
solver and an `info.mouse` route (`{click}`, `{drag}` or `{text}`), which the generic branch of `_mouse_beat`
already follows. The SPEECH screen's beats in WORD and PARTY mode are `&"speech"` beats with `info.slot` added,
or a mode's own beat id with the same `info.mouse` shape. `explainer` is the player's own (the movie branch).

### 3. Word lists: `_check_wrs_lists(sp, problems)` (any day with `speech.wrs`)

For every list in every `speech.wrs.<ear>.lists` with `counts == true` and `player_words > 0`:

- `absi(int(list.pct) - int(list.expected_pct)) <= 8`
- `int(list.pct) == int(list.true_pct)` when the list has no misscore (`int(list.matches) == int(list.player_words)`)
- `bool(list.start_ok)`, and `bool(list.masked) == bool(list.masking_needed)`

### 4. Party lists: `_check_sin_lists(sp, problems)` (any day with `speech.sin`)

For every sheet in `speech.sin.<slot>`:

- every list has 6 `sentences`, and `list.total` equals the sum of the sentences' `count`
- `absf(float(sheet.snr_loss) - float(sheet.true_loss)) <= 3.0` when `int(sheet.lists_done) == 2`
- no sentence with `practice == true` (or an item id of the practice list) is stored in any list

### 5. Day 4 (`nora`): exit 4 on any failure

- `wrs.right` and `wrs.left` exist; the right sheet's `seq` is below every left list's `seq` (better ear first)
- the list ids follow play order (D25): `words_1` on the right, `words_2` first on the left, then `words_3`, then
  `words_4`
- right: `pb_max >= 88` and `band` in `excellent` / `good`; left: the comfortable list's `pct <= 64`
- left: `best_final`, `below_predicted` and `asymmetric` are all true
- a left list with `louder_than > 0` and `rollover == true` on the sheet, whose `mask_db` equals
  `SpeechRules.wrs_mask_level(level_db, test_best_bone, transducer)` (70 on a textbook run; accept 65-75, as
  Hoot's bone stamps wobble, CHAPTER4 §2.2). `test_best_bone` is the lowest of
  `SpeechRules.ear_best_bone(tones, "left")` on the visit's tone results (`SpeechSession.test_best_bone`)
- `speech.wrs_summary.referral == &"refer"`; and `Game.visit.decision == &"refer"` when the visit records one

### 6. Day 5 (`marco`)

- `srt.right`, `srt.left`, `wrs.right` and `wrs.left` exist, all `by_hoot`, right first (`seq`), also with `--full`
  (Hoot's off-screen work goes through `SpeechScreen.run_hidden`, whatever quick visit says)
- both WRS bands are `excellent` or `good`
- `sin.both`, `sin.aided_omni` and `sin.aided_directional` each have `lists_done == 2`, and the 6 list ids are
  distinct
- the unaided band (`sin.both.band`) is `&"moderate"`; both aided sheets have `level_db ==
  SpeechRules.SIN_AIDED_DB` and `band == &""`
- `sin.aided_directional.real_change == true`, or the visit flag `benefit_unsure` with `benefit_db > 0`
- the Daily Decibel's text contains no "beeps" and no "spondees" (the day's `weather` and `sports_script` come
  from the summary, D8)

### 7. Screenshot names (D26)

`_on_speech_presented(ear, test, db, item)` and `_on_speech_stored(ear, test, sheet)` keep Day 3's names for the
SRT (`speech_<ear>_srt_first_word`, `speech_<ear>_srt_stored`). For `wrs` and `sin` the item and the sheet carry
`slot`, and the item carries `list_id`:

```gdscript
func _speech_shot_key(ear: String, test: StringName, slot: String, list_id: String) -> String:
	if test == &"srt":
		return "speech_%s_%s" % [ear, test]
	return "speech_%s_%s_%s" % [slot, test, list_id]
```

- first word: `_speech_shot_key(ear, test, item.get("slot", ear), item.get("list_id", "")) + "_first_word"`
- stored: the sheet's newest list (`(sheet.lists as Array).back().list_id`, else `sheet.list_id`), so each list
  of an ear (comfortable, redo, louder) gets its own `_stored` shot
- the `_low` / `_descent` shot is an SRT idea: keep it for `test == &"srt"` only

Examples: `speech_right_wrs_words_1_first_word`, `speech_left_wrs_words_3_stored`,
`speech_both_sin_party_1_first_word`, `speech_aided_directional_sin_party_5_stored`. The chapter lists (CHAPTER4
§15, CHAPTER5 §13) come from the levels' own `_shot` calls.

### 8. Runs to add to the checks

`tools/autoplay_check.sh --day=4` and `--day=5`, each with keys, with `--mouse`, with `--via-days --pick=nora` /
`--pick=marco` (and `--save=<abs path>`), and once with `--full` (Day 5: Hoot's SRT and WRS stay his).

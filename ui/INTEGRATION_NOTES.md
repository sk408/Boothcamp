# ui/ integration notes

## From the cases branch (Days 6 to 9; CONTRACTS.md §11)

The case runner uses the AudiOtron through its existing plan keys only (`test`, `ear`, `hoot_turn_after`,
`intro`, `bc_freqs`, `masking_controls`, `air_transducer`). Nothing in `ui/` was changed. Requests, all
optional and additive:

- **Hand over at a named frequency.** `hoot_turn_after` counts stamps, so Marina's "watch the low pitches"
  plan has to guess how many stamps reach 500 Hz (8 with TEST_ORDER and a half-octave or two). A plan key
  like `hoot_turn_at: 500` (Hoot takes over once that frequency is stored) would let a case hand the
  player exactly the frequencies it teaches.
- **"Masked air: confirmed" sweep.** When the rules ask for masked air and Hoot runs it at speed, a short
  banner or stamp ("MASKED AIR: CONFIRMED") would tell the player why the chart changed.
- **Skip the bone tickle lesson in Hoot's turns.** In a case, Hoot runs bone conduction at speed; the
  tickle tip still shows once per run. A plan key `tips: false` (or skipping the tip when the current
  turn is Hoot's) would keep the case moving.

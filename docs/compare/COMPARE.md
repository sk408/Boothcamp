# Hearing Aid Compare (the Costco line-up page)

A separate interactive page, built in Godot 4.7.2 like the game's web build, where shoppers compare the hearing
aids sold at Costco hearing aid centres side by side. It is **not part of Booth Camp**: it lives in its own Godot
project under `compare/`, has its own web export, and the game's files are untouched.

## 1. Who it is for

Two readers at once, on the same page:

- **New hearing aid users** read "what does this mean for me": plain words, a short "good for" line per aid, and
  filters phrased as needs ("I want to stream phone calls", "I use the loop at church").
- **Engineers** flip the **Detail** switch and get the full spec sheet: channels and bands, receivers and their
  output, Bluetooth stack (Classic, ASHA, MFi, LE Audio, Auracast), battery hours with and without streaming,
  charge time, IP rating, telecoil, apps, platform and its premium sibling, and every feature name.

Every value carries a numbered source; clicking it shows the source's title, URL and the date it was read.
Anything not confirmed by a primary source (the manufacturer or Costco) is marked **reported** (third-party
source only) or **not verified** (nothing found), never guessed.

## 2. The page

1. **Header.** "Hearing Aid Compare", "Models sold at Costco hearing aid centres", "Specs as of 2026-10-22", the
   Plain / Detail switch.
2. **Need filters** (chips, any mix): rechargeable, streams from iPhone, streams from Android, Auracast ready,
   telecoil, hands-free calls, water and dust resistant (IP68), in-the-canal style available, CROS available.
   Aids that miss a need dim but stay visible, with the missing need named on the card.
3. **The line-up.** Five cards: a neutral 3D shape of the aid's style (no product photos or logos, names as plain
   text), the name, maker and parent, the pair price, three plain "good for" lines and a check box. Tick up to
   three to compare.
4. **Side by side.** A table of the ticked aids, rows grouped (Price and care, Battery, Phone and streaming,
   Sound and processing, Fit and build, Apps). Rows where the ticked aids differ are highlighted; "Only show
   differences" hides the rest. In Plain mode each row has its one-line meaning ("Telecoil: picks up hearing
   loops in theatres and churches").
5. **3D view.** Click an aid's shape to open a turntable: drag to turn, scroll to zoom, the parts labelled
   (microphones, button, receiver wire, receiver, dome; or the shell and vent for in-canal styles). The shapes are
   generic per style (RIC, mini RIC, in-the-ear, in-the-canal), drawn from primitives in code.
6. **Footer.** "Prices change. Check your warehouse." "Not medical advice: a hearing test and a fitting by a
   licensed professional decide which aid suits you." Sources list.

## 3. Data (easy to edit)

- `compare/data/aids.json`: one entry per aid. Each spec is `{ "v": value, "src": ["s3"], "status":
  "verified|reported|unverified", "note": "..." }`.
- `compare/data/prices.json`: prices only, with the date each was checked, so a price change is a one-line edit.
- `compare/data/sources.json`: every source with id, title, URL, kind (manufacturer, Costco, third party) and the
  date read.
- `compare/data/glossary.json`: the plain-language line for each row and filter.

Changing a price or a spec needs no code. The page reads the JSON at start.

## 4. Build and publish

- `compare/project.godot` is its own project (Compatibility renderer, 1280x720 base, canvas stretch). The game's
  editor and export skip it because a folder holding a `project.godot` is another project; the game's
  `test_all_scripts_compile` skips such folders too (one added line).
- The Pages workflow exports it as a second step into `build/web/compare/`, so it is served at
  `<Pages address>/compare/` next to the game.
- Check locally: `compare/tools/check.sh` (unit tests on the data: every spec has a source or a flag, every
  source id exists, prices parse) and a headless web export.

## 5. What the sources say (summary; full citations in the data files)

| Aid | Maker (parent) | Based on | Notes |
|---|---|---|---|
| Sennheiser Sonite Rise | Sennheiser (Sonova) | Phonak Audéo Infinio R (non-Sphere) | In warehouses since March 2026, replacing the Sonite R; Bluetooth Classic, no telecoil, no Auracast |
| Jabra Enhance Pro 30 | Jabra (GN) | GN 360 chip + DNN chip | LE Audio, Auracast out of the box; RIE 60s rechargeable, RIE 62 size 13 with telecoil |
| Philips HearLink 9050 | Philips (Demant) | Oticon Intent | MFi, ASHA, LE Audio; Auracast from firmware 1.3.0; Costco's own page lists 24 fitting bands where reviews say 64 channels |
| Rexton Reach R Plus | Rexton (WS Audiology) | Signia Pure C&G BCT IX 7 class | Bluetooth Classic, telecoil, 54 h battery; Auracast "through a future firmware update" |
| SoundGear AMP | SoundGear (Starkey) | Starkey Edge AI | LE Audio; pilot in about 100 warehouses since late 2025; no public "Amp 2" found |

Primary sources were thin: Costco's support pages exist for the Philips (read) and the old Sonite R; Rexton's own
R Plus pages were read. Jabra's consumer site lists only its Enhance Select line, and soundgear.com lists only hearing
protection, so every Jabra and SoundGear value is marked **reported**. A manufacturer spec sheet or Costco's in-store
sheet for either would let them turn green.

## 6. Questions for Steve (answer by number; the defaults stand otherwise)

1. **Same repo or its own?** Default: this repo, folder `compare/`, served at `<Pages address>/compare/`. A
   separate repo would get its own Pages address.
2. ~~Sonite R or Sonite Rise?~~ Answered 2026-10-22: **Sonite Rise** (items #2027784 pair, #2027785 single).
3. **SoundGear Amp 2?** Every public source and Costco item found says **SoundGear AMP** (Edge AI). Default: show
   "SoundGear AMP" and flag that an "Amp 2" could not be confirmed. If you have the Amp 2 spec sheet, a photo of
   the specs page or the item number is enough.
4. **Which styles?** Default: one card per family, with the styles listed (Jabra RIE 60s and 62; SoundGear mRIC R,
   RIC 312, ITC R, CIC/IIC). A card per style would make about ten cards.
5. **Prices:** show the pair price with "as of" and "varies by state" (default), or hide prices?
6. **Costco's care terms** (180-day trial, warranty, loss and damage, follow-ups): sources disagree (3-year vs
   24-month warranty, one replacement per ear vs per pair). Default: show only what Costco's own pages state and
   say "ask your warehouse" for the rest. Your shop's actual terms would settle it.
7. **Fitting-software limits:** HearingTracker says Costco's software cannot enable tinnitus programs even where
   the platform has them. Default: show such limits with their source. Correct from your experience?
8. **The name:** "Hearing Aid Compare" with "models sold at Costco" as plain text, no Costco or maker logos.
   Default stands unless you want another name.
9. **A "help me choose" quiz** (four questions that set the filters, never naming a winner)? Default: yes, small.
10. **Brand colours on cards?** Default: no, one neutral accent per card so no aid looks favoured.

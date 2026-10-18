#!/usr/bin/env python3
"""Render every case file (story/cases/*.json) as a readable script: docs/CASE_SCRIPTS.md.

The JSON is the source of truth for every line that ships; this page is for reading and signing off.
Usage: python3 tools/case_scripts.py            (writes docs/CASE_SCRIPTS.md)
       python3 tools/case_scripts.py --check    (exit 1 if the page is out of date)
"""
import json
import pathlib
import re
import string
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CASES = ROOT / "story" / "cases"
GAME = ROOT / "autoload" / "game.gd"
OUT = ROOT / "docs" / "CASE_SCRIPTS.md"
CALLS = {"fit": "FIT", "refer": "REFER", "today": "DOCTOR TODAY"}


def case_order():
    """Case ids in Game.CHAPTERS order, then any others."""
    text = GAME.read_text(encoding="utf-8")
    ids = re.findall(r'"case":\s*"([a-z_0-9]+)"', text)
    for p in sorted(CASES.glob("*.json")):
        if p.stem not in ids:
            ids.append(p.stem)
    return ids


def script(lines, out):
    for e in lines:
        if isinstance(e, list) and len(e) == 2:
            out.append(f"- **{e[0]}:** {e[1]}")
        elif isinstance(e, dict):
            if "do" in e:
                out.append(f"- *({e['do'].replace('_', ' ')})*")
            if "react" in e:
                out.append(f"- *(patient: {e['react']})*")
            if "hoot" in e:
                out.append(f"- *(Hoot: {e['hoot'].replace('_', ' ')})*")
            if "choose" in e:
                ch = e["choose"]
                out.append(f"- **Choice:** {ch.get('prompt', '')}")
                for o in ch.get("options", []):
                    out.append(f"  - {o[0]} ({o[1]} pts): Hoot: {o[2]}")


def reply_text(r):
    return " / ".join(r) if isinstance(r, list) else r


def render(c):
    out = []
    sp = c["speaker"]
    out.append(f"## {string.capwords(c['case_title'].lower())} (`{c['id']}`)")
    out.append("")
    out.append(f"**The call:** {CALLS.get(c['decision']['answer'], c['decision']['answer'])}")
    out.append("")
    out.append("### Intro")
    script(c["intro"], out)
    out.append("")
    out.append("Always on the notes: " + "; ".join(f"*{a['text']}*" for a in c.get("always_clues", [])))
    out.append("")
    out.append("### History (pick one per round)")
    out.append("")
    out.append("| Question | Pts | Answer | Clue card | Hoot |")
    out.append("|---|---|---|---|---|")
    for i, rd in enumerate(c["history"], 1):
        for o in rd["options"]:
            who = o[6] if len(o) > 6 and o[6] else sp
            ans = reply_text(o[2])
            if who != sp:
                ans = f"({who}) {ans}"
            hoot = o[5] if len(o) > 5 else ""
            if o[1] == 0:
                hoot = c.get("joke_line", "")
            out.append(f"| R{i}: {o[0]} | {o[1]} | {ans} | {o[3]} | {hoot} |")
    rf = c["red_flags"]
    out.append("")
    out.append(f"Red-flag sweep (if skipped): **Hoot:** {rf['ask_line']} **{sp}:** {reply_text(rf['answer'])}")
    out.append("")
    out.append(f"Red-flag card: *{rf['card'].replace(chr(10), ' / ')}*")
    for ex in rf.get("extra_clues", []):
        out.append(f"; extra card: *{ex['text']}*")
    if c.get("after_history"):
        out.append("")
        script(c["after_history"], out)
    oto = c["otoscopy"]
    out.append("")
    out.append("### Otoscopy")
    out.append(f"Caption: *{oto['caption']}*")
    out.append("")
    script(oto.get("lines", []), out)
    out.append(f"- Card: *{oto['clue']}*")
    ty = c["tymp"]
    out.append("")
    out.append("### Tympanometer")
    out.append(f"Tip: {ty['tip']} ({ty.get('canal', '?')} canal). "
               f"Right: type {ty['right']['type']}, peak {ty['right']['peak_daPa']} daPa, {ty['right']['peak_ml']} mL, canal {ty['right'].get('ecv_ml', '?')} mL. "
               f"Left: type {ty['left']['type']}, peak {ty['left']['peak_daPa']} daPa, {ty['left']['peak_ml']} mL, canal {ty['left'].get('ecv_ml', '?')} mL.")
    out.append("")
    if "quiz" in ty:
        out.append(f"Question: **{ty['quiz']['prompt']}**")
        for o in ty["quiz"]["options"]:
            out.append(f"- {'(right) ' if o[1] else ''}{o[0]}" + (f": Hoot: {o[2]}" if o[2] else ""))
    else:
        if ty["right"]["type"] == ty["left"]["type"]:
            asks = [f"What type are both of {sp}'s tympanograms?"]
        else:
            asks = [f"What type is the {e.upper()} ear's tympanogram?" for e in ("right", "left")]
        for q in asks:
            out.append(f"Question: **{q}** (A / B / C, shuffled)")
        out.append("- A wrong pick: Hoot: Type X would be (its shape). Look where the peak sits, and how tall.")
    out.append("")
    script(ty.get("after", []), out)
    out.append("")
    out.append("### Instructions")
    script(c["instructions"], out)
    out.append("")
    out.append("### Test plan")
    for p in c["audiometry"]:
        who = "Hoot at x8" if p.get("hoot_turn_after", 0) == 0 else f"player for {p['hoot_turn_after']} stamps, then Hoot"
        out.append(f"- {p['ear'].title()} {p['test'].upper()} ({who}): \"{p.get('intro', '')}\"")
        for e in p.get("before", []):
            out.append(f"  - before: **{e[0]}:** {e[1]}")
    out.append("- Then masked bone and masked air wherever the rules ask (Hoot).")
    out.append("")
    out.append("After the tests (said when the measured bone ear agrees with the case; "
               "otherwise **Hoot:** Bone's in. Let's lay it over the air and see what it says.):")
    out.append("")
    script(c.get("after_audiometry", []), out)
    rv = c["reveal"]
    ev = c["evidence"]
    out.append("")
    out.append("### The chart, the shape question, the reveal")
    script(rv.get("ask", []), out)
    out.append(f"- **Question:** {ev['prompt']}")
    for i, o in enumerate(ev["options"]):
        mark = "(right) " if i == ev["answer"] else ""
        why = ev["wrong"][i] if i < len(ev.get("wrong", [])) and ev["wrong"][i] else ""
        out.append(f"  - {mark}{o}" + (f": Hoot: {why}" if why else ""))
    if ev.get("answer_from_type"):
        out.append("  - (graded against the type of loss in the %s ear)" % ev["answer_from_type"])
    out.append(f"- *(the {rv['pattern']} comes alive: {rv['title']})*")
    script(rv.get("lines", []), out)
    if ev.get("right"):
        out.append(f"- **Hoot:** {ev['right']}")
    out.append("")
    out.append("Cards from the chart: " + "; ".join(
        f"*{f['text']}*" + (f" (if {f['when']})" if f.get("when") else "") for f in c["findings"]))
    dec = c["decision"]
    cp = c["clue_pick"]
    out.append("")
    out.append("### The call")
    for k in ["fit", "refer", "today"]:
        mark = " (right)" if k == dec["answer"] else ""
        out.append(f"- **{CALLS[k]}**{mark}: {dec['lines'][k]}")
    out.append("")
    p = cp["prompt"]
    out.append(f"**{p}**" if p.startswith("Present the evidence") else f"Present the evidence: **{p}**")
    out.append(f"- Proof cards (tags): {', '.join(cp['answers'])}. Right: {cp['right_line']}")
    for t, line in cp.get("right_lines", {}).items():
        out.append(f"  - {t}: {line}")
    out.append(f"- Wrong card (default): {cp['wrong_line']}")
    for t, line in cp.get("wrong_lines", {}).items():
        out.append(f"  - {t}: {line}")
    out.append("")
    out.append("### Payoff")
    script(c["payoff"], out)
    out.append("")
    out.append("### The Daily Decibel")
    for g, h in c["paper"]["headlines"].items():
        out.append(f"- {g}: **{h}** {c['paper'].get('subheads', {}).get(g, '')}")
    out.append("")
    return out


def main():
    lines = ["# Case scripts", "",
             "Generated from `story/cases/*.json` by `python3 tools/case_scripts.py`. Do not edit by hand: change the",
             "JSON and run the tool again. Every Hoot line is 18 words or fewer (`story/tests/test_cases.gd`). Choices",
             "are shown in file order; the game shuffles them.", ""]
    for cid in case_order():
        p = CASES / f"{cid}.json"
        if p.exists():
            lines += render(json.loads(p.read_text(encoding="utf-8")))
    text = "\n".join(lines).rstrip() + "\n"
    if "--check" in sys.argv:
        if not OUT.exists() or OUT.read_text(encoding="utf-8") != text:
            print("docs/CASE_SCRIPTS.md is out of date: run python3 tools/case_scripts.py")
            sys.exit(1)
        return
    OUT.write_text(text, encoding="utf-8")
    print(f"wrote {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()

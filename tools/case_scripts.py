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
RUNNER = ROOT / "story" / "level_case.gd"
RULES = ROOT / "core" / "cases" / "case_rules.gd"
OUT = ROOT / "docs" / "CASE_SCRIPTS.md"
CALLS = {"fit": "FIT", "refer": "REFER", "today": "DOCTOR TODAY"}
WHEN_LABELS = {
    "symmetric": "if the ears match",
    "asymmetric": "if the ears differ",
    "conductive": "only when the chart reads conductive",
    "abg_flag": "only with a gap of 15+ at 500, 1k and 2k",
}


def rules_number(pattern):
    """A number from core/cases/case_rules.gd, so this page reads a flat tymp the way the game does."""
    m = re.search(pattern, RULES.read_text(encoding="utf-8"))
    if not m:
        sys.exit(f"case_scripts.py: {pattern} not found in {RULES}")
    return float(m.group(1))


# CaseRules: a flat tymp's canal volume reads blocked below TYMP_BLOCKED_ECV, a hole above the adult band
TYMP_BLOCKED_ECV = rules_number(r"const TYMP_BLOCKED_ECV := ([\d.]+)")
TYMP_ADULT_ECV_MAX = rules_number(r"const TYMP_ADULT_ECV := Vector2\([\d.]+, ([\d.]+)\)")


def runner_line(name):
    """One of level_case.gd's own Hoot lines (const NAME := "..."), so this page stays in step."""
    m = re.search(r'const %s := "([^"]*)"' % name, RUNNER.read_text(encoding="utf-8"))
    if not m:
        sys.exit(f"case_scripts.py: const {name} not found in {RUNNER}")
    return m.group(1)


def tymp_desc(t):
    if t.get("type") == "B":
        ecv = t.get("ecv_ml", "?")
        reads = "?"
        if isinstance(ecv, (int, float)):
            reads = "blocked" if ecv < TYMP_BLOCKED_ECV else ("hole" if ecv > TYMP_ADULT_ECV_MAX else "fluid")
        return f"type B, flat, canal {ecv} mL: reads {reads}"
    return (f"type {t.get('type', '?')}, peak {t.get('peak_daPa', '?')} daPa, {t.get('peak_ml', '?')} mL, "
            f"canal {t.get('ecv_ml', '?')} mL")


def card(text, kind):
    return f"*{text}*" + (" (red card)" if kind == "flag" else "")


def case_order():
    """Case ids in Game.CHAPTERS order, then any others."""
    text = GAME.read_text(encoding="utf-8")
    ids = re.findall(r'"case":\s*"([a-z_0-9]+)"', text)
    for p in sorted(CASES.glob("*.json")):
        if p.stem not in ids:
            ids.append(p.stem)
    return ids


def script(lines, out, indent=""):
    for e in lines:
        if isinstance(e, list) and len(e) == 2:
            out.append(f"{indent}- **{e[0]}:** {e[1]}")
        elif isinstance(e, dict):
            if "do" in e:
                out.append(f"{indent}- *({e['do'].replace('_', ' ')})*")
            if "react" in e:
                out.append(f"{indent}- *(patient: {e['react']})*")
            if "hoot" in e:
                out.append(f"{indent}- *(Hoot: {e['hoot'].replace('_', ' ')})*")
            if "choose" in e:
                ch = e["choose"]
                out.append(f"{indent}- **Choice:** {ch.get('prompt', '')}")
                for o in ch.get("options", []):
                    out.append(f"{indent}  - {o[0]} ({o[1]} pts): Hoot: {o[2]}")


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
    other = "LEFT" if oto.get("ear", "right") == "right" else "RIGHT"
    out.append(f"First caption: *{runner_line('OTHER_EAR_CAPTION') % (c['speaker'], other)}*")
    out.append("")
    otoscopy(oto, out)
    ty = c["tymp"]
    out.append("")
    out.append("### Tympanometer")
    out.append(f"Tip: {ty['tip']} ({ty.get('canal', '?')} canal). "
               f"Right: {tymp_desc(ty['right'])}. Left: {tymp_desc(ty['left'])}.")
    out.append("")
    if "quiz" in ty:
        out.append(f"Question: **{ty['quiz']['prompt']}**")
        for o in ty["quiz"]["options"]:
            line = o[2] if len(o) > 2 else ""
            out.append(f"- {'(right) ' if o[1] else ''}{o[0]}" + (f": Hoot: {line}" if line else ""))
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
    plan(c["audiometry"], out)
    out.append("- Then masked bone and masked air wherever the rules ask (Hoot). When masked bone ran and no "
               f"ear needed masked air: **Hoot:** {runner_line('NO_MASKED_AIR')}")
    out.append("")
    out.append("After the tests (said when every ear with bone agrees with the case; "
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
    plug = f", with the {rv['plug']} in the gap" if rv.get("plug") else ""
    out.append(f"- *(the {rv['pattern']} comes alive{plug}: {rv['title']})*")
    script(rv.get("lines", []), out)
    if ev.get("right"):
        out.append(f"- **Hoot:** {ev['right']}")
    out.append("")
    out.append("Cards from the chart: " + "; ".join(
        card(f["text"], f.get("kind", "clue")) + (f" ({WHEN_LABELS.get(f['when'], f['when'])})" if f.get("when") else "")
        for f in c["findings"]))
    if any(f.get("when") for f in c["findings"]):
        out.append("")
        out.append(f"If the chart and the truth disagree on any of those: **Hoot:** {runner_line('MISMATCH')}")
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
    if "retest" in c:
        retest(c["retest"], out)
    out.append("")
    out.append("### The Daily Decibel")
    for g, h in c["paper"]["headlines"].items():
        out.append(f"- {g}: **{h}** {c['paper'].get('subheads', {}).get(g, '')}")
    for k, e in c["paper"].get("wrong_first", {}).items():
        out.append(f"- First stamp {CALLS.get(k, k)} (S to C): **{e['headline']}** {e.get('subhead', '')}".rstrip())
    out.append("")
    return out


def otoscopy(oto, out):
    view = oto.get("view", "clear")
    out.append(f"Caption: *{oto.get('caption', '')}*" + (f" (view: {view})" if view != "clear" else ""))
    out.append("")
    script(oto.get("lines", []), out)
    if oto.get("clue"):
        out.append(f"- Card: {card(oto['clue'], oto.get('kind', 'clue'))}")


def plan(steps, out):
    for p in steps:
        if p.get("montage"):
            who = "Hoot's montage"
        elif p.get("hoot_turn_after", 0) == 0:
            who = "Hoot at x8"
        else:
            n = p["hoot_turn_after"]
            who = f"player for {n} stamp{'' if n == 1 else 's'}, then Hoot"
        out.append(f"- {p['ear'].title()} {p['test'].upper()} ({who}): \"{p.get('intro', '')}\"")
        if p.get("before"):
            out.append("  - before:")
            script(p["before"], out, "    ")


def retest(rt, out):
    out.append("")
    out.append(f"### The retest: *{rt.get('card', 'LATER')}* (unscored)")
    script(rt.get("intro", []), out)
    if "otoscopy" in rt:
        out.append("")
        out.append("Otoscopy again:")
        otoscopy(rt["otoscopy"], out)
    if "tymp" in rt:
        ty = rt["tymp"]
        out.append("")
        out.append(f"Tymp again (the tip seals, no question): Right: {tymp_desc(ty['right'])}. Left: {tymp_desc(ty['left'])}.")
        out.append("")
        script(ty.get("after", []), out)
    out.append("")
    script(rt.get("before", []), out)
    script(rt.get("instructions", []), out)
    out.append("")
    plan(rt["audiometry"], out)
    rv = rt["reveal"]
    out.append("")
    out.append(f"- *(the new chart flies up over the old one, dashed \"{rv.get('label', 'BEFORE')}\": {rv.get('title', '')})*")
    out.append("- When the measured %s ear agrees with the story:" % rv["ear"])
    script(rv.get("lines", []), out, "  ")
    out.append(f"- Otherwise: **Hoot:** {runner_line('RETEST_NEUTRAL')}")
    out.append("")
    script(rt.get("payoff", []), out)


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

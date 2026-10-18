#!/usr/bin/env python3
"""Audio-safety check for a Day 2 (bone conduction + masking) Movie Maker capture.

Usage: python3 -I tools/analyze_movie_bc.py <capture.wav> <run.log> [fps]
  capture.wav  stereo PCM from the movie (ffmpeg -i bc.avi -vn -c:a pcm_s16le bc.wav)
  run.log      stdout of tools/movie_ac.tscn --day=2: MOVIE_TONE_ON <ear> <freq> <db> <frame> <transducer>,
               MOVIE_TONE_OFF <ear> <freq> <db> <frame>, MOVIE_MASK <masked ear> <freq> <dB EM> <on> <frame>

The harness mutes the Sfx, Music and Voice buses, so the capture holds only the ToneGenerator output
(Tones bus at tone_volume 0.8 and Master 0.8). Checks:
  1. ceiling: no sample above -12 dBFS anywhere; masker samples (masker-only stretches) at or below
     -24 dBFS (the masker ceiling) minus the bus volumes;
  2. tones: the test ear carries the tone at the AudioSafety level (steady-state RMS within 0.5 dB,
     peak within 0.3 dB); with the masker off the other ear is digital zero for air tones and exactly
     BONE_CROSS_DB (-10 dB, gain 0.316) of the tone for bone tones; with the masker on, an air tone
     leaks less than -20 dB into the noise ear (regression gain) and a bone tone's other-ear level
     matches noise + cross-feed within 3 dB;
  3. masker: the noise ear's RMS while the masker plays alone matches AudioSafety.masker_to_rms(dB EM)
     (mean within 1 dB, each stretch within 3 dB);
  4. no stray sound: each channel is cut into non-zero runs and every run must be a logged tone in
     that ear, the bone cross-feed of a tone in the other ear, or the masker in its own ear; so the
     test ear holds only its tones (the masker never reaches it) and silence is digital zero.
Tones are matched to runs by the generator's measured output lag (Hoot's x8 turns play tones only
~5 frames apart). At the quietest tones the level tolerances widen by the 16-bit rounding.
Exit 0 when every check passes, 1 otherwise.
"""
import math
import sys
import wave

import numpy as np

BUS_DB = 2 * 20 * math.log10(0.8)  # Game defaults: tone_volume 0.8, master_volume 0.8
BONE_CROSS = 10 ** (-10 / 20)      # ToneGenerator.BONE_CROSS_DB


def hl_rms_dbfs(hl):
    return min(max(-75.0 + 0.6 * hl, -90.0), -12.0)


def hl_peak_dbfs(hl):
    return min(hl_rms_dbfs(hl) + 20 * math.log10(math.sqrt(2.0)), -12.0)


def masker_rms_dbfs(db_em):
    return min(max(-75.0 + 0.6 * db_em - 6.0, -90.0), -24.0)


def db(x):
    return 20 * math.log10(max(float(x), 1e-12))


def rms(x):
    return float(np.sqrt(np.mean(x ** 2))) if len(x) else 0.0


def main():
    wav_path, log_path = sys.argv[1], sys.argv[2]
    fps = float(sys.argv[3]) if len(sys.argv) > 3 else 30.0
    with wave.open(wav_path, "rb") as w:
        sr = w.getframerate()
        assert w.getnchannels() == 2, "expected stereo"
        a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64).reshape(-1, 2) / 32768.0
    ch = {"left": a[:, 0], "right": a[:, 1]}
    n = len(a)
    spf = sr / fps
    print(f"capture: {n / sr:.1f} s at {sr} Hz")
    ok = True
    pk = {e: db(np.abs(ch[e]).max()) for e in ch}
    print(f"whole-file peak: L {pk['left']:.1f} dBFS, R {pk['right']:.1f} dBFS (ceiling -12)")
    if max(pk.values()) > -12.0:
        print("FAIL: something peaks above -12 dBFS"); ok = False

    # ---- events
    tones, on, masks = [], {}, []
    for line in open(log_path, errors="replace"):
        p = line.split()
        if not p:
            continue
        if p[0] == "MOVIE_TONE_ON":
            on[p[1]] = (int(p[2]), int(p[3]), int(p[4]), p[5] if len(p) > 5 else "phones")
        elif p[0] == "MOVIE_TONE_OFF" and p[1] in on:
            f, d, fr, tr = on.pop(p[1])
            tones.append({"ear": p[1], "f": f, "db": d, "on": fr, "off": int(p[4]), "tr": tr})
        elif p[0] == "MOVIE_MASK":
            masks.append({"ear": p[1], "f": int(p[2]), "db": int(p[3]), "on": p[4] == "1", "fr": int(p[5])})
    if not tones:
        print("FAIL: no tones logged"); return 1

    # ---- sound runs: contiguous non-zero stretches of each channel (gaps under 3 ms merged, since a
    # very quiet sine rounds to zero near its zero crossings). Every run must be explained by a tone in
    # that ear, the bone cross-feed of a tone in the other ear, or the masker in that ear.
    LSB = 1.0 / 32768.0
    gap = int(0.003 * sr)

    def find_runs(x):
        nz = np.nonzero(x)[0]
        if not nz.size:
            return []
        br = np.nonzero(np.diff(nz) > gap)[0]
        starts = np.concatenate(([nz[0]], nz[br + 1]))
        ends = np.concatenate((nz[br], [nz[-1]])) + 1
        return [[int(s), int(e), None] for s, e in zip(starts, ends)]

    runs = {e: find_runs(ch[e]) for e in ch}

    # the generator's output lag (AudioStreamGenerator buffer): from tones with a quiet gap before them
    lags = []
    last_off = {"left": -10 ** 9, "right": -10 ** 9}
    for t in tones:
        if t["on"] - last_off[t["ear"]] > 20:
            lo = int(t["on"] * spf)
            for r in runs[t["ear"]]:
                if r[0] >= lo:
                    if r[0] - lo < 15 * spf:
                        lags.append(r[0] - lo)
                    break
        last_off[t["ear"]] = t["off"]
    lag = float(np.median(lags)) if lags else 0.0
    jit = 1.5 * spf  # event-to-audio jitter allowance (the generator refills once per frame)
    print(f"generator lag: median {lag / spf:.1f} frames ({lag / sr * 1000:.0f} ms) from {len(lags)} isolated tones")

    # each tone -> the run in its test ear that starts nearest to on + lag
    for t in tones:
        want = t["on"] * spf + lag
        best, bd = None, 3 * spf
        for r in runs[t["ear"]]:
            if r[2] is None and abs(r[0] - want) < bd:
                best, bd = r, abs(r[0] - want)
        if best is not None:
            best[2] = t
            t["s0"], t["s1"] = best[0], best[1]

    def mask_state(frame):
        st = None
        for m in masks:
            if m["fr"] <= frame:
                st = m
            else:
                break
        return st if st is not None and st["on"] else None

    # masker-on periods per ear, in samples (lag applied, ramps and jitter allowed)
    mper = []
    for i, m in enumerate(masks):
        if not m["on"]:
            continue
        end = next((mm["fr"] for mm in masks[i + 1:] if not mm["on"] or mm["ear"] != m["ear"]), None)
        e = n if end is None else int(end * spf + lag + jit + 0.06 * sr)
        mper.append((m["ear"], int(m["fr"] * spf + lag - jit), e))

    def in_masker(ear, s, e):
        return any(me == ear and ms <= s and e <= mend for me, ms, mend in mper)

    # ---- tones
    other_of = {"left": "right", "right": "left"}
    rows = {"air_off": [], "bone_off": [], "air_on": [], "bone_on": []}
    fails = []
    for t in tones:
        if "s0" not in t:
            fails.append(f"tone {t} not found in its channel")
            continue
        s0, s1 = t["s0"], t["s1"]
        want_len = (t["off"] - t["on"]) * spf
        if abs((s1 - s0) - want_len) > 2 * spf:
            fails.append(f"tone {t['ear']} {t['f']} Hz {t['db']} dB: sound lasts {(s1 - s0) / spf:.1f} frames, the tone {want_len / spf:.1f}")
        st0, st1 = s0 + int(0.035 * sr), s1 - int(0.035 * sr)
        if st1 - st0 < int(0.03 * sr):
            continue
        test, other = ch[t["ear"]][st0:st1], ch[other_of[t["ear"]]][st0:st1]
        want_rms = hl_rms_dbfs(t["db"]) + BUS_DB
        want_pk = hl_peak_dbfs(t["db"]) + BUS_DB
        pk_lsb = 10 ** (want_pk / 20) / LSB
        rms_lsb = 10 ** (want_rms / 20) / LSB
        # 16-bit rounding (and the engine's 44.1 -> 48 kHz resampler): up to 1 LSB on the peak,
        # about 0.3 LSB rms of rounding error (not white at a few LSB, so 0.5 LSB is allowed)
        ptol = 0.3 + db(1.0 + 1.0 / pk_lsb)
        rtol = 0.5 + 10 * math.log10(1.0 + (0.5 / rms_lsb) ** 2)
        rdev = db(rms(test)) - want_rms
        pdev = db(np.abs(test).max()) - want_pk
        k = float(np.dot(other, test) / max(np.dot(test, test), 1e-30))
        ms = mask_state(t["on"])
        bone = t["tr"] == "bone"
        key = ("bone" if bone else "air") + ("_on" if ms else "_off")
        row = {"t": t, "rdev": rdev, "pdev": pdev, "k": k, "mask": ms}
        rows[key].append(row)
        if abs(rdev) > rtol or pdev > ptol:
            fails.append(f"level {t['ear']} {t['f']} Hz {t['db']} dB {t['tr']}: rms {rdev:+.2f} dB (tol {rtol:.2f}), peak {pdev:+.2f} dB (tol {ptol:.2f})")
        if ms is not None and ms["ear"] == t["ear"]:
            fails.append(f"masker in the TEST ear during {t}")
        if not ms:
            if bone:
                # exact gain where the tone is loud enough to resolve it in 16 bits; never louder anywhere
                ktol = max(0.01, 0.5 / pk_lsb)
                if abs(k - BONE_CROSS) > ktol:
                    fails.append(f"bone cross-feed gain {k:.3f} (want {BONE_CROSS:.3f} +-{ktol:.3f}) at {t['f']} Hz {t['db']} dB")
                if np.abs(other).max() / LSB > math.ceil(pk_lsb * BONE_CROSS + 1.0):
                    fails.append(f"bone cross-feed peaks above -10 dB (+1 LSB) at {t['f']} Hz {t['db']} dB")
            if not bone and np.any(other):
                fails.append(f"air tone leaks into the other ear at {t['f']} Hz {t['db']} dB (k {k:.4f})")
        else:
            if not bone and abs(k) > 0.1:
                fails.append(f"air tone with masker: other-ear tone gain {k:.3f} (> -20 dB) at {t['f']} Hz")
            if bone:
                want = math.sqrt(10 ** ((masker_rms_dbfs(ms["db"]) + BUS_DB) / 10) + (BONE_CROSS * 10 ** (want_rms / 20)) ** 2)
                odev = db(rms(other)) - db(want)
                row["odev"] = odev
                if abs(odev) > 3.0:
                    fails.append(f"bone tone + masker: other ear {odev:+.1f} dB off noise + cross-feed at {t['f']} Hz")
    for key, rs in rows.items():
        if not rs:
            continue
        rd = np.array([r["rdev"] for r in rs])
        pd = np.array([r["pdev"] for r in rs])
        ks = np.array([r["k"] for r in rs])
        lv = [hl_peak_dbfs(r["t"]["db"]) + BUS_DB + r["pdev"] for r in rs]
        extra = ""
        if key == "bone_on":
            od = np.array([r.get("odev", 0.0) for r in rs])
            extra = f"; other ear vs noise + cross-feed {od.mean():+.2f} dB (worst {od[np.abs(od).argmax()]:+.2f})"
        print(f"tones {key:8s}: {len(rs):3d}  level RMS {rd.mean():+.3f} dB (range {rd.min():+.3f}..{rd.max():+.3f}), "
              f"peak worst {pd.max():+.2f} dB, test-ear peaks {min(lv):.1f}..{max(lv):.1f} dBFS; "
              f"other-ear tone gain {ks.mean():.4f} (range {ks.min():.4f}..{ks.max():.4f}){extra}")
    print(f"  (bone cross-feed target gain {BONE_CROSS:.4f} = -10 dB; air with the masker off: other ear digital zero;"
          f" level tolerances widen by the 16-bit rounding at the quietest tones)")

    # ---- every run explained? (unexplained sound = a leak: masker in the test ear, a stray tone, ...)
    tone_spans = {e: [(t["s0"], t["s1"], t) for t in tones if "s0" in t and t["ear"] == e] for e in ch}
    unexplained = []
    for e in ch:
        for r in runs[e]:
            if r[2] is not None:
                continue
            s, en = r[0], r[1]
            # cross-feed of a bone tone in the other ear (same span)
            if any(t["tr"] == "bone" and ts - jit <= s and en <= te + jit for ts, te, t in tone_spans[other_of[e]]):
                continue
            if in_masker(e, s, en):
                continue
            unexplained.append((e, s / spf, en / spf))
    masked_test_ears = sorted(set(t["ear"] for t in tones if mask_state(t["on"]) is not None))
    if unexplained:
        for e, a0, a1 in unexplained[:8]:
            fails.append(f"unexplained sound in the {e} ear at frames {a0:.1f}..{a1:.1f}")
    print(f"sound runs: L {len(runs['left'])}, R {len(runs['right'])}; unexplained: {len(unexplained)}"
          f" (every non-zero stretch is a logged tone, its bone cross-feed, or the masker in its own ear)")
    print(f"  test ear(s) during masked tests {masked_test_ears}: "
          + ("only the logged tones, digital zero between them (the masker never reaches the test ear)" if not
             any(e in masked_test_ears for e, _, _ in unexplained) else "NOT clean"))

    # ---- masker-only stretches (masker on, no tone audio within 50 ms): noise level and ceiling
    busy = np.zeros(n, dtype=bool)
    pad = int(0.05 * sr)
    for e in ch:
        for ts, te, _ in tone_spans[e]:
            busy[max(0, ts - pad):min(n, te + pad)] = True
    mrows, mask_peak = [], -200.0
    for i, m in enumerate(masks):
        if not m["on"]:
            continue
        nxt = masks[i + 1]["fr"] if i + 1 < len(masks) else None
        s0 = int(m["fr"] * spf + lag + jit + 0.1 * sr)
        s1 = n if nxt is None else int(nxt * spf + lag - jit)
        if s1 - s0 < int(0.04 * sr):
            continue
        free = ~busy[s0:s1]
        # longest tone-free piece of this stretch
        idx = np.nonzero(free)[0]
        if idx.size < int(0.04 * sr):
            continue
        br = np.nonzero(np.diff(idx) > 1)[0]
        starts = np.concatenate(([idx[0]], idx[br + 1]))
        ends = np.concatenate((idx[br], [idx[-1]])) + 1
        for a0, a1 in zip(starts, ends):
            if a1 - a0 < int(0.04 * sr):
                continue
            noise = ch[m["ear"]][s0 + a0:s0 + a1]
            dev = db(rms(noise)) - (masker_rms_dbfs(m["db"]) + BUS_DB)
            mask_peak = max(mask_peak, db(np.abs(noise).max()))
            mrows.append((m["db"], m["f"], dev, (a1 - a0) / sr))
    silent_runs = sum(len(runs[e]) for e in ch)
    if mrows:
        devs = np.array([r[2] for r in mrows])
        w = np.array([r[3] for r in mrows])
        mean = float(np.sum(devs * w) / np.sum(w))
        print(f"masker-only stretches: {len(mrows)} ({w.sum():.1f} s), levels {min(r[0] for r in mrows)}..{max(r[0] for r in mrows)} dB EM at "
              f"{sorted(set(r[1] for r in mrows))} Hz; noise-ear RMS vs masker_to_rms: mean {mean:+.2f} dB "
              f"(range {devs.min():+.2f}..{devs.max():+.2f}); noise peak {mask_peak:.1f} dBFS (ceiling {-24 + BUS_DB:.1f})")
        if abs(mean) > 1.0 or np.abs(devs).max() > 3.0:
            fails.append("masker level differs from AudioSafety.masker_to_rms")
        if mask_peak > -24.0 + BUS_DB + 0.1:
            fails.append("masker peak above its -24 dBFS ceiling")
    else:
        fails.append("no masker-only stretch measured")
    masked_ears = sorted(set(m["ear"] for m in masks if m["on"]))
    print(f"masker ears: {masked_ears} (tests on the right ear: the masker must be in the left)")
    if any(m["on"] and m["ear"] == "right" for m in masks):
        fails.append("masker switched on in the right (test) ear")
    for f in fails[:20]:
        print("FAIL:", f)
    if fails:
        ok = False
    print("AUDIO_CHECK", "PASS" if ok else "FAIL")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())

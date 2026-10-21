#!/usr/bin/env python3
"""Audio-safety check for a Movie Maker capture of the AudiOtron (tools/movie_ac.tscn).

Usage: python3 -I tools/analyze_movie_audio.py <capture.wav> <run.log> [fps]
  capture.wav  stereo PCM extracted from the movie (ffmpeg -i ac.avi -vn -c:a pcm_s16le ac.wav)
  run.log      the game's stdout, with MOVIE_TONE_ON/OFF <ear> <freq> <db> <frame> lines

Method. UI sounds and voices are mono, so the side signal (R - L) is exactly zero except where a
one-ear tone plays. Each logged tone is located in the side signal (the generator buffer delays the
audio by a few frames), then:
  - channel attribution (silence test): in 2 ms blocks where no UI sound plays, the other ear must be
    digital zero while the test ear carries the tone (never the reverse);
  - level: steady-state side RMS (which a leak into the other ear would lower) and peak vs AudioSafety (-71 dBFS RMS at 0 dB HL, +0.6 dB per dB,
    peak capped at -12 dBFS) minus the default Tones and Master bus volumes;
  - ceiling: no sample anywhere in the file above -12 dBFS.

(Speech) --speech: a Day 3 capture (tools/movie_check.sh --day=3; tools/movie_ac.tscn --day=3 logs
MOVIE_TEST srt <ear> <frame>, MOVIE_WORD_ON <ear> <db HL> <frame> <murmur ms> <item id> and
MOVIE_NOISE <noise ear> <db EM> <on 0/1> <frame>). The harness mutes the UI buses, so the capture
holds only SpeechVoice: the word murmur in the test ear, the speech noise in the other one. Checks:
  - words: each logged word is found in its test ear at the generator lag; it plays out in full (no
    word cut short by the next one); its RMS over the voiced syllables (the non-zero runs, gaps under
    3 ms merged) matches AudioSafety.speech_to_rms (-75 dBFS at 0 dB HL, +0.6 per dB, -9, capped at
    -27) minus the bus volumes, within 0.5 dB (wider at the quietest words for the 16-bit rounding);
    with the noise off the other ear is digital zero during the word, with it on the noise ear's
    level during the word stays that of the noise alone (a word leaking there would raise it);
  - noise: only ever in the ear opposite the test ear; its RMS where it plays alone (no word within
    50 ms, past its 50 ms ramp) matches AudioSafety.masker_to_rms (-6, capped at -24) at each logged
    level (mean within 0.5 dB, each stretch within 1.5 dB); no noise sample above -24 dBFS minus the
    bus volumes;
  - no stray sound: every non-zero stretch of either channel is a logged word in its test ear or the
    noise in its ear while it is on; the ceiling: no sample above -12 dBFS;
  - the whole visit: the log has MOVIE_DONE and no AUTOPLAY_FAILED, both ears have a MOVIE_TEST line
    and measured words, and each ear has words with the noise on in the other ear (a stalled or
    cut-off capture of one ear never passes).
Usage: python3 -I tools/analyze_movie_audio.py <speech.wav> <run.log> [fps] --speech
Exit 0 when every check passes, 1 otherwise.
"""
import math
import sys
import wave

import numpy as np

BUS_DB = 2 * 20 * math.log10(0.8)  # Game defaults: tone_volume 0.8, master_volume 0.8


TONE_BOOST_DB = 4.0  # AudioSafety.TONE_BOOST_DB (clinical review E7): tones only, never the masker


def hl_rms_dbfs(hl):
    return min(max(-75.0 + TONE_BOOST_DB + 0.6 * hl, -90.0), -12.0)


def hl_peak_dbfs(hl):
    return min(hl_rms_dbfs(hl) + 20 * math.log10(math.sqrt(2.0)), -12.0)


def db(x):
    return 20 * math.log10(max(float(x), 1e-12))


def speech_rms_dbfs(hl):
    return min(max(-75.0 + 0.6 * hl - 9.0, -90.0), -27.0)


def masker_rms_dbfs(db_em):
    return min(max(-75.0 + 0.6 * db_em - 6.0, -90.0), -24.0)


def bandpass(x, sr, f, rel=0.04):
    spec = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1.0 / sr)
    spec[(fr < f * (1 - rel)) | (fr > f * (1 + rel))] = 0
    return np.fft.irfft(spec, len(x))


def main():
    if "--speech" in sys.argv:
        args = [a for a in sys.argv[1:] if a != "--speech"]
        return speech_main(args[0], args[1], float(args[2]) if len(args) > 2 else 30.0)
    wav_path, log_path = sys.argv[1], sys.argv[2]
    fps = float(sys.argv[3]) if len(sys.argv) > 3 else 30.0
    with wave.open(wav_path, "rb") as w:
        sr = w.getframerate()
        assert w.getnchannels() == 2, "expected stereo"
        a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64).reshape(-1, 2) / 32768.0
    L, R = a[:, 0], a[:, 1]
    S = R - L
    spf = int(round(sr / fps))
    print(f"capture: {len(a) / sr:.1f} s at {sr} Hz")
    file_peak = max(np.abs(L).max(), np.abs(R).max())
    print(f"whole-file peak: L {db(np.abs(L).max()):.1f} dBFS, R {db(np.abs(R).max()):.1f} dBFS (ceiling -12)")

    tones, on = [], {}
    for line in open(log_path, errors="replace"):
        p = line.split()
        if not p or not p[0].startswith("MOVIE_TONE_"):
            continue
        if p[0] == "MOVIE_TONE_ON":
            on[p[1]] = (int(p[2]), int(p[3]), int(p[4]))
        elif p[1] in on:
            f, d, fr = on.pop(p[1])
            tones.append((p[1], f, d, fr, int(p[4])))

    # (v3) Tone onsets: the side signal is cut into non-zero runs (gaps under 3 ms merged) and each
    # logged tone takes the run that starts nearest its ON frame plus the generator's output lag
    # (measured on tones with a quiet gap before them). Searching forward from the ON frame instead
    # picks up the tail of the previous tone during Hoot's x8 turn, where tones are ~6 frames apart.
    nzs = np.nonzero(S)[0]
    runs = []
    if nzs.size:
        br = np.nonzero(np.diff(nzs) > int(0.003 * sr))[0]
        runs = [[int(a0), int(a1) + 1, False] for a0, a1 in zip(np.concatenate(([nzs[0]], nzs[br + 1])), np.concatenate((nzs[br], [nzs[-1]])))]
    lags, last_off = [], -10 ** 9
    for ear, f, d, f_on, f_off in tones:
        if f_on - last_off > 20:
            r = next((r for r in runs if r[0] >= f_on * spf), None)
            if r is not None and r[0] - f_on * spf < 15 * spf:
                lags.append(r[0] - f_on * spf)
        last_off = f_off
    lag = float(np.median(lags)) if lags else 0.0
    print(f"generator lag: median {lag / spf:.1f} frames ({lag / sr * 1000:.0f} ms) from {len(lags)} isolated tones; side-signal runs {len(runs)}")

    tone_mask = np.zeros(len(S), bool)
    blk = int(0.002 * sr)        # 2 ms blocks for the silence test
    rows = []
    for ear, f, d, f_on, f_off in tones:
        want = f_on * spf + lag
        best = min((r for r in runs if not r[2]), key=lambda r: abs(r[0] - want), default=None)
        if best is None or abs(best[0] - want) > 3 * spf:
            rows.append((ear, f, d, None))
            continue
        best[2] = True
        s0 = best[0]                                      # audio onset (generator buffer lag)
        s1 = min(len(S), max(best[1], s0 + (f_off - f_on) * spf) + int(0.08 * sr))   # + release ramp tail
        tone_mask[s0:s1] = True
        ramp = int(0.035 * sr)
        st0, st1 = s0 + ramp, s0 + (f_off - f_on) * spf - int(0.005 * sr)
        if st1 - st0 < int(0.03 * sr):
            continue
        test, other = (R, L) if ear == "right" else (L, R)
        side = test[st0:st1] - other[st0:st1]
        rms_dev = db(np.sqrt((side ** 2).mean())) - (hl_rms_dbfs(d) + BUS_DB)
        peak_dev = db(np.abs(S[s0:s1]).max()) - (hl_peak_dbfs(d) + BUS_DB)
        # silence test: in blocks where one channel is digital zero, which one is it?
        iso = wrong = both_quiet = 0
        for b0 in range(st0, st1 - blk, blk):
            t_zero = not np.any(test[b0:b0 + blk])
            o_zero = not np.any(other[b0:b0 + blk])
            if o_zero and not t_zero:
                iso += 1
            elif t_zero and not o_zero:
                wrong += 1
            elif t_zero and o_zero:
                both_quiet += 1
        rows.append((ear, f, d, (iso, wrong, both_quiet, rms_dev, peak_dev)))

    ok = True
    missing = [r for r in rows if r[3] is None]
    good = [r for r in rows if r[3] is not None]
    outside = np.abs(S[~tone_mask]).max() if (~tone_mask).any() else 0.0
    print(f"side signal outside the tones: max |R-L| = {db(outside):.1f} dBFS (-240 = exactly mono)")
    print(f"tones logged {len(tones)}, measured {len(good)} (right {sum(1 for r in good if r[0] == 'right')}, left {sum(1 for r in good if r[0] == 'left')}), not found in audio {len(missing)}")
    if good:
        iso_t = sum(1 for r in good if r[3][0] > 0)
        wrong_b = sum(r[3][1] for r in good)
        quiet_b = sum(r[3][2] for r in good)
        iso_b = sum(r[3][0] for r in good)
        rd = np.array([r[3][3] for r in good])
        pd = np.array([r[3][4] for r in good])
        print(f"silence test (2 ms blocks during tones): tone alone in the TEST ear {iso_b} blocks, alone in the OTHER ear {wrong_b}, test ear silent {quiet_b}")
        print(f"  {iso_t} of {len(good)} tones have stretches with no other sound, and in every one the other ear is digital zero")
        print(f"steady-state level vs AudioSafety mapping: RMS mean {rd.mean():+.3f} dB (range {rd.min():+.3f}..{rd.max():+.3f}); peak worst {pd[np.abs(pd).argmax()]:+.2f} dB")
        print("  (a tone leaking a share k into the other ear would lower the side RMS by 20*log10(1-k))")
        for ear in ("right", "left"):
            lv = [hl_peak_dbfs(r[2]) + BUS_DB + r[3][4] for r in good if r[0] == ear]
            if lv:
                print(f"{ear} ear tones: peak {min(lv):.1f} .. {max(lv):.1f} dBFS at {min(r[2] for r in good if r[0] == ear)}..{max(r[2] for r in good if r[0] == ear)} dB HL")
        if wrong_b > 0 or quiet_b > 0:
            print("FAIL: tone found in the wrong ear, or missing from the test ear"); ok = False
        if np.abs(rd).max() > 0.5:
            print("FAIL: a tone level differs from the AudioSafety mapping by more than 0.5 dB"); ok = False
    else:
        print("FAIL: no tones measured"); ok = False
    if missing:
        print("FAIL: logged tones with no audio"); ok = False
    if outside > 0:
        print("FAIL: stereo content outside the tones"); ok = False
    if db(file_peak) > -12.0:
        print("FAIL: something peaks above -12 dBFS"); ok = False
    print("AUDIO_CHECK", "PASS" if ok else "FAIL")
    return 0 if ok else 1


def speech_main(wav_path, log_path, fps):
    """(Speech) Day 3: the words and the speech noise (see the module docstring)."""
    with wave.open(wav_path, "rb") as w:
        sr = w.getframerate()
        assert w.getnchannels() == 2, "expected stereo"
        a = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64).reshape(-1, 2) / 32768.0
    ch = {"left": a[:, 0], "right": a[:, 1]}
    other_of = {"left": "right", "right": "left"}
    n = len(a)
    spf = sr / fps
    LSB = 1.0 / 32768.0
    print(f"capture: {n / sr:.1f} s at {sr} Hz (speech mode)")
    fails = []
    pk = {e: db(np.abs(ch[e]).max()) for e in ch}
    print(f"whole-file peak: L {pk['left']:.1f} dBFS, R {pk['right']:.1f} dBFS (ceiling -12)")
    if max(pk.values()) > -12.0:
        fails.append("something peaks above -12 dBFS")

    words, noise, tests = [], [], []
    done, gave_up = False, []
    for line in open(log_path, errors="replace"):
        p = line.split()
        if p and p[0] == "MOVIE_DONE":
            done = True
        elif p and p[0].startswith("AUTOPLAY_FAILED"):
            gave_up.append(line.strip())
        if len(p) >= 6 and p[0] == "MOVIE_WORD_ON":
            words.append({"ear": p[1], "db": int(p[2]), "fr": int(p[3]), "len": int(p[4]) / 1000.0 * sr, "id": p[5]})
        elif len(p) >= 5 and p[0] == "MOVIE_NOISE":
            noise.append({"ear": p[1], "db": int(p[2]), "on": p[3] == "1", "fr": int(p[4])})
        elif len(p) >= 4 and p[0] == "MOVIE_TEST":
            tests.append((p[2], int(p[3])))
    if not words:
        print("FAIL: no words logged")
        print("AUDIO_CHECK FAIL")
        return 1

    def test_ear(frame):
        e = None
        for te, tf in tests:
            if tf <= frame:
                e = te
        return e

    gap = int(0.003 * sr)

    def find_runs(x):
        nz = np.nonzero(x)[0]
        if not nz.size:
            return []
        br = np.nonzero(np.diff(nz) > gap)[0]
        starts = np.concatenate(([nz[0]], nz[br + 1]))
        ends = np.concatenate((nz[br], [nz[-1]])) + 1
        return [[int(s0), int(e0), False] for s0, e0 in zip(starts, ends)]

    runs = {e: find_runs(ch[e]) for e in ch}

    # the generator's output lag: first sound in the test ear after each word's frame
    lags = []
    for wd in words:
        lo = wd["fr"] * spf
        r = next((r for r in runs[wd["ear"]] if r[0] >= lo), None)
        if r is not None and r[0] - lo < 15 * spf:
            lags.append(r[0] - lo)
    lag = float(np.median(lags)) if lags else 0.0
    jit = 1.5 * spf
    print(f"generator lag: median {lag / spf:.1f} frames ({lag / sr * 1000:.0f} ms) from {len(lags)} words")

    # noise periods per ear, in samples: [ear, db, start, end] (start/end at the event frames + lag)
    periods = []
    for i, ev in enumerate(noise):
        if not ev["on"]:
            continue
        end = noise[i + 1]["fr"] if i + 1 < len(noise) else None
        periods.append([ev["ear"], ev["db"], ev["fr"] * spf + lag, n if end is None else end * spf + lag, ev["fr"]])

    def noise_at(ear, s0, s1):
        """The noise periods of `ear` overlapping samples s0..s1 (ramps and jitter allowed)."""
        return [pp for pp in periods if pp[0] == ear and pp[2] - jit < s1 and s0 < pp[3] + jit + 0.06 * sr]

    for pp in periods:
        te = test_ear(pp[4])
        if te is not None and pp[0] == te:
            fails.append(f"speech noise switched on in the TEST ear ({te}) at frame {pp[4]}")

    # ---- words
    rows, cut, leak_rows, quiet_checked = [], [], [], 0
    spans = {"left": [], "right": []}
    masked_words = {"left": 0, "right": 0}
    for wd in words:
        want = wd["fr"] * spf + lag
        best = min((r for r in runs[wd["ear"]] if not r[2]), key=lambda r: abs(r[0] - want), default=None)
        if best is None or abs(best[0] - want) > 3 * spf:
            fails.append(f"word {wd['id']} ({wd['ear']} {wd['db']} dB) not found in its ear at frame {wd['fr']}")
            continue
        s0 = best[0]
        mine = [r for r in runs[wd["ear"]] if not r[2] and s0 <= r[0] <= s0 + wd["len"] + 2 * spf]
        for r in mine:
            r[2] = True
        s1 = max(r[1] for r in mine)
        spans[wd["ear"]].append((s0, s1))
        if s1 - s0 < wd["len"] - 2 * spf:
            cut.append(wd)
        x = ch[wd["ear"]]
        energy = sum(float(np.sum(x[r[0]:r[1]] ** 2)) for r in mine)
        count = sum(r[1] - r[0] for r in mine)
        want_rms = speech_rms_dbfs(wd["db"]) + BUS_DB
        rms_lsb = 10 ** (want_rms / 20) / LSB
        rtol = 0.5 + 10 * math.log10(1.0 + (0.5 / rms_lsb) ** 2)
        dev = db(math.sqrt(energy / count)) - want_rms
        rows.append((wd, dev, rtol, db(np.abs(x[s0:s1]).max())))
        o = ch[other_of[wd["ear"]]][int(max(0, s0 - jit)):int(min(n, s1 + jit))]
        on = noise_at(other_of[wd["ear"]], s0, s1)
        masked_words[wd["ear"]] += 1 if on else 0
        if not on:
            quiet_checked += 1
            if np.any(o):
                fails.append(f"word {wd['id']} ({wd['ear']} {wd['db']} dB) heard in the other ear with the noise off")
        elif len(on) == 1:
            # the noise ear during the word, past the noise's ramp: still the noise alone?
            a0, a1 = int(max(s0, on[0][2] + jit + 0.1 * sr)), int(min(s1, on[0][3] - jit))
            if a1 - a0 > int(0.1 * sr):
                nd = db(math.sqrt(float(np.mean(ch[other_of[wd["ear"]]][a0:a1] ** 2)))) - (masker_rms_dbfs(on[0][1]) + BUS_DB)
                leak_rows.append(nd)
    if rows:
        devs = np.array([r[1] for r in rows])
        bad = [r for r in rows if abs(r[1]) > r[2]]
        lv = [r[0]["db"] for r in rows]
        print(f"words logged {len(words)} (right {sum(1 for w in words if w['ear'] == 'right')}, left {sum(1 for w in words if w['ear'] == 'left')}), "
              f"measured {len(rows)} at {min(lv)}..{max(lv)} dB HL")
        print(f"  RMS over the voiced syllables vs AudioSafety.speech_to_rms: mean {devs.mean():+.3f} dB (range {devs.min():+.3f}..{devs.max():+.3f}); "
              f"loudest word peak {max(r[3] for r in rows):.1f} dBFS")
        print(f"  {len(rows) - len(cut)} of {len(rows)} words play out in full; with the noise off ({quiet_checked} words) the other ear is "
              + ("digital zero during every word" if not any("heard in the other ear" in f for f in fails) else "NOT silent"))
        for r in bad[:6]:
            fails.append(f"word {r[0]['id']} ({r[0]['ear']} {r[0]['db']} dB HL) at {r[1]:+.2f} dB from the speech_to_rms level (tolerance {r[2]:.2f})")
        for wd in cut[:6]:
            fails.append(f"word {wd['id']} ({wd['ear']} {wd['db']} dB) cut short (run the capture at --speed=1)")
    else:
        fails.append("no words measured")
    if leak_rows:
        lr = np.array(leak_rows)
        print(f"  {len(lr)} words with the noise on: the noise ear's level during the word vs the noise alone {lr.mean():+.2f} dB (worst {lr.max():+.2f})")
        if lr.max() > 1.5:
            fails.append("a word raises the noise ear's level: speech leaking into the noise ear")

    # ---- noise where it plays alone (no word within 50 ms, past the ramp)
    busy = np.zeros(n, dtype=bool)
    pad = int(0.05 * sr)
    for e in spans:
        for s0, s1 in spans[e]:
            busy[max(0, s0 - pad):min(n, s1 + pad)] = True
    nrows, npeak = [], -200.0
    for pp in periods:
        s0, s1 = int(pp[2] + jit + 0.1 * sr), int(pp[3] - jit)
        if s1 - s0 < int(0.04 * sr):
            continue
        x = ch[pp[0]][s0:s1]
        npeak = max(npeak, db(np.abs(x).max()))
        idx = np.nonzero(~busy[s0:s1])[0]
        if idx.size < int(0.3 * sr):
            continue
        noise_alone = x[idx]
        want = masker_rms_dbfs(pp[1]) + BUS_DB
        rms_lsb = 10 ** (want / 20) / LSB
        tol = 1.5 + 10 * math.log10(1.0 + (0.5 / rms_lsb) ** 2)
        nrows.append((pp[1], db(math.sqrt(float(np.mean(noise_alone ** 2)))) - want, idx.size / sr, tol, pp[0]))
    if nrows:
        d = np.array([r[1] for r in nrows])
        wgt = np.array([r[2] for r in nrows])
        mean = float(np.sum(d * wgt) / np.sum(wgt))
        print(f"speech noise: {len(nrows)} stretches alone ({wgt.sum():.1f} s) at {min(r[0] for r in nrows)}..{max(r[0] for r in nrows)} dB EM "
              f"in {sorted(set(r[4] for r in nrows))}; RMS vs masker_to_rms: mean {mean:+.2f} dB (range {d.min():+.2f}..{d.max():+.2f}); "
              f"peak {npeak:.1f} dBFS (ceiling {-24 + BUS_DB:.1f})")
        if abs(mean) > 0.5 or any(abs(r[1]) > r[3] for r in nrows):
            fails.append("speech noise level differs from AudioSafety.masker_to_rms")
        if npeak > -24.0 + BUS_DB + 0.1:
            fails.append("speech noise peak above its -24 dBFS ceiling")
    else:
        fails.append("no speech-noise stretch measured (MASK never on long enough)")

    # ---- every run explained: a word in its test ear, or the noise in its ear while on
    unexplained = []
    for e in ch:
        for r in runs[e]:
            if r[2] or noise_at(e, r[0], r[1]):
                continue
            unexplained.append((e, r[0] / spf, r[1] / spf))
    print(f"sound runs: L {len(runs['left'])}, R {len(runs['right'])}; unexplained {len(unexplained)}"
          " (every non-zero stretch is a logged word in its test ear or the speech noise in the other ear)")
    for e, a0, a1 in unexplained[:8]:
        fails.append(f"unexplained sound in the {e} ear at frames {a0:.1f}..{a1:.1f}")

    # ---- the whole visit: both ears tested, each with words measured and some under the noise
    if not done:
        fails.append("no MOVIE_DONE: the recording stopped before the visit ended (a stall or a timeout)")
    for g in gave_up[:2]:
        fails.append(f"the bot gave up: {g}")
    tested = sorted(set(te for te, _ in tests))
    measured = sorted(set(r[0]["ear"] for r in rows))
    print(f"ears tested {tested}, with measured words {measured}; words under the noise: "
          f"right {masked_words['right']}, left {masked_words['left']}")
    if tested != ["left", "right"] or measured != ["left", "right"]:
        fails.append(f"both ears must be tested and measured (tested {tested}, measured {measured})")
    for e in ("right", "left"):
        if e in measured and masked_words[e] == 0:
            fails.append(f"no {e}-ear word with the speech noise on in the other ear (MASK is on for words 4-7)")
    for f in fails[:20]:
        print("FAIL:", f)
    print("AUDIO_CHECK", "FAIL" if fails else "PASS")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())

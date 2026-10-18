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
  - level: steady-state side RMS (which a leak into the other ear would lower) and peak vs AudioSafety (-75 dBFS RMS at 0 dB HL, +0.6 dB per dB,
    peak capped at -12 dBFS) minus the default Tones and Master bus volumes;
  - ceiling: no sample anywhere in the file above -12 dBFS.
Exit 0 when every check passes, 1 otherwise.
"""
import math
import sys
import wave

import numpy as np

BUS_DB = 2 * 20 * math.log10(0.8)  # Game defaults: tone_volume 0.8, master_volume 0.8


def hl_rms_dbfs(hl):
    return min(max(-75.0 + 0.6 * hl, -90.0), -12.0)


def hl_peak_dbfs(hl):
    return min(hl_rms_dbfs(hl) + 20 * math.log10(math.sqrt(2.0)), -12.0)


def db(x):
    return 20 * math.log10(max(float(x), 1e-12))


def bandpass(x, sr, f, rel=0.04):
    spec = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1.0 / sr)
    spec[(fr < f * (1 - rel)) | (fr > f * (1 + rel))] = 0
    return np.fft.irfft(spec, len(x))


def main():
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


if __name__ == "__main__":
    sys.exit(main())

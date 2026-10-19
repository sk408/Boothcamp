#!/usr/bin/env bash
# Audio-safety movie check: records both ears of air conduction with Movie Maker (MJPEG AVI + PCM),
# then analyses the audio per tone: routing (test ear only), level vs AudioSafety, -12 dBFS ceiling.
# Usage: tools/movie_check.sh /abs/out/dir [--speed=6]     (~5 min on llvmpipe, ~500 MB AVI)
#        tools/movie_check.sh /abs/out/dir --day=2         (v3: Bonnie's bone + masking tests, 640x360,
#          UI sounds muted; tools/analyze_movie_bc.py checks tones, the bone cross-feed and the masker)
#        tools/movie_check.sh /abs/out/dir --day=3         (Speech: Mike's SRT, both ears, speech noise
#          for part of each, 640x360, UI sounds muted, at --speed=1 so no word is cut short;
#          tools/analyze_movie_audio.py --speech checks the words and the noise)
# Any other --day, and any --chapter, is refused (exit 2) before anything is recorded. On Day 3 a recording
# that does not exit cleanly (a stall, a timeout) fails the check before the analysis.
set -uo pipefail
OUT="${1:?usage: tools/movie_check.sh /abs/out/dir [--day=1|2|3]}"; shift || true
DAY=1
for a in "$@"; do
  case "$a" in
    --day=*) DAY="${a#--day=}" ;;
    --chapter=*) echo "movie_check.sh: $a is not supported: pick the movie with --day=1, --day=2 or --day=3." \
                   "Nothing recorded." >&2
                 exit 2 ;;
  esac
done
case "$DAY" in
  1|2|3) ;;
  *) echo "movie_check.sh: --day=$DAY is not supported: the movie records --day=1 (Gus's air)," \
       "--day=2 (Bonnie's bone and masking) or --day=3 (Mike's speech). Nothing recorded." >&2
     exit 2 ;;
esac
cd "$(dirname "$0")/.."
mkdir -p "$OUT"
godot --headless --path . --import >/dev/null 2>&1
if [[ "$DAY" == 2 ]]; then
  timeout 2400 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
    --fixed-fps 30 --resolution 640x360 --write-movie "$OUT/bc.avi" -- --scene=res://tools/movie_ac.tscn --autoplay --speed=6 "$@" \
    > "$OUT/run.log" 2>&1
  ffmpeg -loglevel error -y -i "$OUT/bc.avi" -vn -c:a pcm_s16le "$OUT/bc.wav"
  python3 -I tools/analyze_movie_bc.py "$OUT/bc.wav" "$OUT/run.log"
  exit $?
fi
if [[ "$DAY" == 3 ]]; then
  # --speed=1 comes last so it wins over a --speed passed in: every word plays out in real time
  timeout 1800 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
    --fixed-fps 30 --resolution 640x360 --write-movie "$OUT/speech.avi" -- --scene=res://tools/movie_ac.tscn --autoplay "$@" --speed=1 \
    > "$OUT/run.log" 2>&1
  gst=$?
  if [[ $gst -ne 0 ]]; then
    # the bot's stall (2) or timeout (3), or timeout's kill (124): the movie holds part of the visit at most
    echo "FAIL: the Day 3 recording exited with status $gst (see $OUT/run.log)"
    echo "AUDIO_CHECK FAIL"
    exit 1
  fi
  ffmpeg -loglevel error -y -i "$OUT/speech.avi" -vn -c:a pcm_s16le "$OUT/speech.wav"
  python3 -I tools/analyze_movie_audio.py "$OUT/speech.wav" "$OUT/run.log" --speech
  exit $?
fi
timeout 1500 xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
  --fixed-fps 30 --write-movie "$OUT/ac.avi" -- --scene=res://tools/movie_ac.tscn --autoplay --speed=6 "$@" \
  > "$OUT/run.log" 2>&1
ffmpeg -loglevel error -y -i "$OUT/ac.avi" -vn -c:a pcm_s16le "$OUT/ac.wav"
python3 -I tools/analyze_movie_audio.py "$OUT/ac.wav" "$OUT/run.log"

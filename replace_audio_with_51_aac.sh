#!/bin/bash
set -euo pipefail

# Check dependencies
command -v ffmpeg >/dev/null || { echo "ffmpeg not found"; exit 1; }
command -v mkvmerge >/dev/null || { echo "mkvmerge not found"; exit 1; }
command -v mkvpropedit >/dev/null || { echo "mkvpropedit not found"; exit 1; }

# Parse arguments
if [[ $# -lt 2 || $# -gt 3 ]]; then
    echo "Usage: $0 <donor_video.mkv> <recipient_video.mkv> [audio_track_index]"
    echo "  audio_track_index: defaults to 0 (first audio track)"
    exit 1
fi

if [[ -d "$1" ]]; then
  SOURCE_DIR="$1"
else
  SOURCE_VIDEO="$1"
fi

TARGET_VIDEO="$2"
AUDIO_TRACK="${3:-0}"

# Validate audio track is a number
if ! [[ "$AUDIO_TRACK" =~ ^[0-9]+$ ]]; then
    echo "Error: audio_track_index must be a number"
    exit 1
fi

# Temp files
ENCODED_AUDIO="/dev/shm/$$.encoded_audio.m4a"
TEMP_JSON="/dev/shm/$$.json"
OUTPUT_VIDEO="/dev/shm/$$.output_with_new_audio.mkv"

cleanup() {
 rm -f "$ENCODED_AUDIO" "$TEMP_JSON"
}
trap cleanup EXIT

# Extract JSON value from grep output
get_json_value() {
    grep "$1" "$TEMP_JSON" | awk -F ':' '{print $2}' | tr -d ' ",'
}

if [[ -d "${SOURCE_DIR:-}" ]]; then
  lc_target="${TARGET_VIDEO,,}"
  found=""
  shopt -s nullglob
  for f in "$SOURCE_DIR"/*; do
    name=${f##*/}                     # strip directory
    if [[ "${name,,}" == "$lc_target" ]]; then
      SOURCE_VIDEO="$SOURCE_DIR/$name"
      if [[ ! -f "${SOURCE_VIDEO:-}" ]]; then
        echo "Could not find $SOURCE_VIDEO using case-insensitive matching in the source directory $SOURCE_DIR"
        exit 1
      fi
      break
    fi
  done
  shopt -u nullglob
fi

#        acompressor=threshold=-21dB:ratio=4:attack=200:release=1000,\
#      dynaudnorm=f=500:g=5:p=0.85:s=5:m=3,\
#      acompressor=threshold=-18dB:ratio=4:attack=20:release=250:knee=3dB:makeup=2dB,\
#      alimiter=limit=0.9:attack=5:release=50"\

# Apply normalization (audio-only)
ffmpeg -y -hide_banner -nostats -drc_scale 2.66 -i "$SOURCE_VIDEO" -vn -map "a:$AUDIO_TRACK" \
    -af "aresample=resampler=soxr:osf=flt,\
      firequalizer=gain_entry='entry(20,0);entry(150,1.2);entry(3000,1.2);entry(20000,0)',\
      pan=5.1|c0=c0|c1=c1|c2=1.10*c2|c3=c3|c4=c4|c5=c5"\
    -c:a pcm_f32le -ar 48000 -ac 6 -channel_layout 5.1 -f wav - | \
  pv -a -T -B 5000M -L 25M -D 60  |\
  fdkaac -m 3 -p 2 --afterburner 1 -w 15024 -o "$ENCODED_AUDIO" -

# Replace audio in target video
mkvmerge -o "$OUTPUT_VIDEO" --clusters-in-meta-seek --no-date \
    --aac-is-sbr 0:0 --audio-tracks 0 "$ENCODED_AUDIO" \
    --no-audio "$TARGET_VIDEO"

# Add metadata
mkvpropedit "$OUTPUT_VIDEO" --add-track-statistics-tags \
  --edit track:1 --set name="Video track" \
  --edit track:2 --set name="Audio track"

# Replace original
mv -v -f "$OUTPUT_VIDEO" "$TARGET_VIDEO"

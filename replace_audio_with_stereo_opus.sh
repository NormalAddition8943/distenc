#!/bin/bash
set -euo pipefail

# Check dependencies
command -v ffmpeg >/dev/null
command -v mkvmerge >/dev/null
command -v mkvpropedit >/dev/null

# Check input arguments
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <donor_video.mkv> <recipient_video.mkv>"
    exit 1
fi

SOURCE_VIDEO="$1"
TARGET_VIDEO="$2"
ENCODED_AUDIO="/dev/shm/$$.encoded_audio.mka"
TEMP_JSON="/dev/shm/$$.json"
OUTPUT_VIDEO="/dev/shm/$$.output_with_new_audio.mkv"

echo "Step 1: Analyzing loudness (pass 1)..."
ffmpeg -hide_banner -nostats -i "$SOURCE_VIDEO" -vn -map a:0 \
  -af loudnorm=I=-23:TP=-2.0:LRA=7:print_format=json \
  -f null - 2>&1 | tee "$TEMP_JSON"

# Extract values using grep + awk (BusyBox-compatible)
measured_I=$(grep 'input_i' "$TEMP_JSON" | awk -F ':' '{print $2}' | tr -d ' ",')
measured_TP=$(grep 'input_tp' "$TEMP_JSON" | awk -F ':' '{print $2}' | tr -d ' ",')
measured_LRA=$(grep 'input_lra' "$TEMP_JSON" | awk -F ':' '{print $2}' | tr -d ' ",')
measured_thresh=$(grep 'input_thresh' "$TEMP_JSON" | awk -F ':' '{print $2}' | tr -d ' ",')
offset=$(grep 'target_offset' "$TEMP_JSON" | awk -F ':' '{print $2}' | tr -d ' ",')
echo
echo "Step 2: Applying normalization with:"
echo "measured_I=$measured_I"
echo "measured_TP=$measured_TP"
echo "measured_LRA=$measured_LRA"
echo "measured_thresh=$measured_thresh"
echo "offset=$offset"
echo

# Apply normalization (audio-only)
ffmpeg -y -hide_banner -nostats -i "$SOURCE_VIDEO" -vn -map a:0 \
  -filter:a loudnorm=I=-23:TP=-2.0:LRA=7:measured_I="$measured_I":measured_TP="$measured_TP":measured_LRA="$measured_LRA":measured_thresh="$measured_thresh":offset="$offset" \
  -ac 2 -c:a libopus -b:a 80k -frame_duration 60 "$ENCODED_AUDIO"

# Replace audio in target video
mkvmerge -o "$OUTPUT_VIDEO" --clusters-in-meta-seek --no-date \
    --audio-tracks 0 "$ENCODED_AUDIO" \
    --no-audio "$TARGET_VIDEO"

# Add metadata
mkvpropedit "$OUTPUT_VIDEO" --add-track-statistics-tags \
  --edit track:1 --set name="Video Track" \
  --edit track:2 --set name="Audio Track"

# Replace original
mv -v -f "$OUTPUT_VIDEO" "$TARGET_VIDEO"

# Clean up
rm -f "$ENCODED_AUDIO" "$TEMP_JSON"

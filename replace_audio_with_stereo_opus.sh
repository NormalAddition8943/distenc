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

SOURCE_VIDEO="$1"
TARGET_VIDEO="$2"
AUDIO_TRACK="${3:-0}"

# Validate audio track is a number
if ! [[ "$AUDIO_TRACK" =~ ^[0-9]+$ ]]; then
    echo "Error: audio_track_index must be a number"
    exit 1
fi

# Temp files
ENCODED_AUDIO="/dev/shm/$$.encoded_audio.mka"
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

echo "Step 1: Analyzing loudness (pass 1) from audio track $AUDIO_TRACK..."
ffmpeg -hide_banner -nostats -i "$SOURCE_VIDEO" -vn -map "a:$AUDIO_TRACK" \
  -af loudnorm=I=-23:TP=-2.0:LRA=7:print_format=json \
  -f null - 2>&1 | tee "$TEMP_JSON"

# Extract values
measured_I=$(get_json_value 'input_i')
measured_TP=$(get_json_value 'input_tp')
measured_LRA=$(get_json_value 'input_lra')
measured_thresh=$(get_json_value 'input_thresh')
offset=$(get_json_value 'target_offset')

echo
echo "Step 2: Applying normalization with:"
echo "  measured_I=$measured_I"
echo "  measured_TP=$measured_TP"
echo "  measured_LRA=$measured_LRA"
echo "  measured_thresh=$measured_thresh"
echo "  offset=$offset"
echo

# Apply normalization (audio-only)
ffmpeg -y -hide_banner -nostats -i "$SOURCE_VIDEO" -vn -map "a:$AUDIO_TRACK" \
  -filter:a "loudnorm=I=-22:TP=-1.5:LRA=5:measured_I=$measured_I:measured_TP=$measured_TP:measured_LRA=$measured_LRA:measured_thresh=$measured_thresh:offset=$offset,aresample=matrix_encoding=dplii" \
  -ac 2 -c:a libopus -b:a 96k -frame_duration 60 "$ENCODED_AUDIO"

# Replace audio in target video
mkvmerge -o "$OUTPUT_VIDEO" --clusters-in-meta-seek --no-date \
    --audio-tracks 0 "$ENCODED_AUDIO" \
    --no-audio "$TARGET_VIDEO"

# Add metadata
mkvpropedit "$OUTPUT_VIDEO" --add-track-statistics-tags \
  --edit track:1 --set name="Video track" \
  --edit track:2 --set name="Audio track, stereo matrixed using Dolby Pro Logic II"

# Replace original
mv -v -f "$OUTPUT_VIDEO" "$TARGET_VIDEO"

echo "Done!"

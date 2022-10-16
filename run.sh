#!/bin/bash
set -e


EXTENSION=${EXTENSION:-mp4}
ENCODER=${ENCODER:-libx264}
PRESET=${PRESET:-veryfast}
CRF=${CRF:-35}
THREADS=${THREADS:-1}
CPU_LIMIT=${CPU_LIMIT:-30}
PRIORITY=${PRIORITY:-19}
ANALYZEDURATION=${ANALYZEDURATION:-100000000}
PROBESIZE=${PROBESIZE:-100000000}
WATCH=${WATCH:-/watch}
OUTPUT=${OUTPUT:-/output}
STORAGE=${STORAGE:-/storage}

run() {
  cd "$WATCH" || exit
  FILES=$(find . -type f -not -path '*/\.*'  | egrep '.*')
  cd ..
  echo "$FILES" | while read -r FILE
  do
    process "$FILE"
  done;
}

process() {
  file=$1
  filepath=${file:2}
  input="$WATCH"/"$filepath"
  destination="$STORAGE"/"${filepath%.*}"."$EXTENSION"
  cd "$STORAGE" && mkdir -p "$(dirname "$filepath")" && cd ..

  echo $(date +"%Y-%m-%d-%T")

  trap 'exit' INT
  nice -"$PRIORITY" cpulimit -l "$CPU_LIMIT" -- ffmpeg \
    -hide_banner \
    -y \
    -loglevel warning \
    -i "$input" \
    -map 0:v -map 0:a -map 0:a -c:v copy -c:a:1 copy -c:a:0 aac -channel_layout:a:0 stereo -filter:a:0 "pan=stereo|FL<0.5*c2+0.707*c0+0.707*c4+0.5*c3|FR<0.5*c2+0.707*c1+0.707*c5+0.5*c3" -filter:a:0 "volume=1.2" -b:a:0 128k \
    -threads "$THREADS" \
    "$destination"

  killall ffmpeg >/dev/null

  echo "Finished encoding $filepath"
  echo $(date +"%Y-%m-%d-%T")

  path=${filepath%/*}
  mv "$STORAGE"/"$path" "$OUTPUT"/"$path"
  rm -rf "$WATCH"/"$path"
}

processes=$(ps aux | grep -i "ffmpeg" | awk '{print $11}')
for i in $processes; do
  if [ "$i" == "ffmpeg" ] ;then
    echo 'Waiting for current econding to complete...'
    exit 0
  fi
done

run

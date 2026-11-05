#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
bundle="$project_dir/build/NoteSpeech.app"
mkdir -p "$bundle/Contents/MacOS" "$project_dir/build/swift-cache"
cp "$project_dir/src/voice/native/Info.plist" "$bundle/Contents/Info.plist"
xcrun swiftc -parse-as-library -O -target "$(uname -m)-apple-macosx13.0" -module-cache-path "$project_dir/build/swift-cache" \
  -framework AppKit -framework AVFoundation -framework Speech \
  "$project_dir/src/voice/native/NoteSpeech.swift" -o "$bundle/Contents/MacOS/NoteSpeech"
codesign --force --sign - --identifier com.fretrelations.notespeech "$bundle"
printf 'Built %s\n' "$bundle"

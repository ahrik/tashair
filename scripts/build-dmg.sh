#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
bash scripts/build-app.sh
stage="$project_dir/temp/dmg-stage"
mkdir -p "$stage"
ditto temp/outputs/TashAir.app "$stage/TashAir.app"
ln -sfn /Applications "$stage/Applications"
cp docs/INSTALLATION.md "$stage/INSTALLATION.md"
cp LICENSE "$stage/LICENSE"
hdiutil create -ov -volname TashAir -srcfolder "$stage" -format UDZO temp/outputs/TashAir.dmg
cd temp/outputs
shasum -a 256 TashAir.dmg TashAir-macOS.zip > SHA256SUMS

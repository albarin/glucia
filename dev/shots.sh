#!/bin/sh
# Usage: dev/shots.sh [en|es]. Builds dev/screenshots.yaml, renders every test case and joins them in dev/shots/sheet.png.
set -e
cd "$(dirname "$0")/.."
.venv/bin/esphome -s shots_lang "${1:-en}" compile dev/screenshots.yaml > dev/shots.log 2>&1 || { tail -40 dev/shots.log; exit 1; }
rm -rf dev/.esphome/snapshots
perl -e 'alarm 60; exec @ARGV' dev/.esphome/build/glucia-shots/.pioenvs/glucia-shots/program >> dev/shots.log 2>&1
mkdir -p dev/shots
.venv/bin/python - <<'PY'
from pathlib import Path
from PIL import Image, ImageDraw
shots = sorted(Path("dev/.esphome/snapshots/glucia-shots").glob("*.bmp"))
cols, w, h, label = 2, 480, 320, 22
rows = (len(shots) + cols - 1) // cols
sheet = Image.new("RGB", (cols * (w + 10) + 10, rows * (h + label + 10) + 10), "white")
d = ImageDraw.Draw(sheet)
for i, p in enumerate(shots):
    x, y = 10 + (i % cols) * (w + 10), 10 + (i // cols) * (h + label + 10)
    d.text((x, y + 4), p.stem, fill="black")
    sheet.paste(Image.open(p), (x, y + label))
sheet.save("dev/shots/sheet.png")
print(f"{len(shots)} shots -> dev/shots/sheet.png")
PY

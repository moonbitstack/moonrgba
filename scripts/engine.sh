#!/bin/sh
# Builds the library into docs/engine/ for the page's live board.
#
# The result is a build artefact: docs/engine/ is ignored by git, and the deploy
# workflow builds it again rather than trusting what is on disk.
set -eu
cd "$(dirname "$0")/.."
moon build --target js --release src/examples/browser
mkdir -p docs/engine
cp _build/js/release/build/examples/browser/browser.js docs/engine/moonrgba.js
echo "docs/engine/moonrgba.js $(wc -c < docs/engine/moonrgba.js) bytes"

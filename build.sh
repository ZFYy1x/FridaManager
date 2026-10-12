#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building FridaManager (Dopamine roothide only) ==="

# ---------------------------------------------------------------------------
# Dopamine roothide (iphoneos-arm64) — the only supported build target.
# Requires the roothide/theos fork (https://github.com/roothide/theos).
# ---------------------------------------------------------------------------
cp control.roothide control
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide

echo ""
echo "=== Build complete ==="
echo "Packages are in: $(pwd)/packages/"
ls -la packages/*.deb 2>/dev/null || echo "No packages found — check build output above."

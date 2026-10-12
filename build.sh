#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building FridaManager ==="

# ---------------------------------------------------------------------------
# Default build: Dopamine roothide (iphoneos-arm64)
# ---------------------------------------------------------------------------
echo ""
echo "--- Building roothide (iphoneos-arm64) [默认] ---"
cp control.roothide control
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide

echo ""
echo "--- Renaming roothide package ---"
for f in packages/*_iphoneos-arm64.deb; do
    [ -f "$f" ] && mv "$f" "${f%_iphoneos-arm64.deb}_iphoneos-arm64_roothide.deb"
done

# ---------------------------------------------------------------------------
# Rootless (iphoneos-arm64) — Dopamine / palera1n rootless
# ---------------------------------------------------------------------------
echo ""
echo "--- Building rootless (iphoneos-arm64) ---"
cp control.rootless control
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless

echo ""
echo "--- Renaming rootless package ---"
for f in packages/*_iphoneos-arm64.deb; do
    [ -f "$f" ] && mv "$f" "${f%_iphoneos-arm64.deb}_iphoneos-arm64_rootless.deb"
done

# ---------------------------------------------------------------------------
# Rootful (iphoneos-arm) — unc0ver / checkra1n
# ---------------------------------------------------------------------------
echo ""
echo "--- Building rootful (iphoneos-arm) ---"
cp control.rootful control
make clean
make package FINALPACKAGE=1

echo ""
echo "--- Renaming rootful package ---"
for f in packages/*_iphoneos-arm.deb; do
    [ -f "$f" ] && mv "$f" "${f%_iphoneos-arm.deb}_iphoneos-arm_rootful.deb"
done

# Restore roothide control as the default
cp control.roothide control

echo ""
echo "=== Build complete ==="
echo "Packages are in: $(pwd)/packages/"
ls -la packages/*.deb 2>/dev/null || echo "No packages found — check build output above."

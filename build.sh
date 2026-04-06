#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Building FridaManager ==="

# Build rootful (iphoneos-arm)
echo ""
echo "--- Building rootful (iphoneos-arm) ---"
cp control.rootful control
make clean
make package FINALPACKAGE=1

# Build rootless (iphoneos-arm64)
echo ""
echo "--- Building rootless (iphoneos-arm64) ---"
cp control.rootless control
make clean
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=rootless

# Restore rootful control as default
cp control.rootful control

echo ""
echo "=== Build complete ==="
echo "Packages are in: $(pwd)/packages/"
ls -la packages/*.deb 2>/dev/null || echo "No packages found — check build output above."

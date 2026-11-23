#!/bin/bash
# Restore the Epson L3260 / Konica bizhub 206 scan profiles for the NATIVE
# NAPS2 RPM (installed in the image by files/scripts/install-vendor-apps.sh).
# Run on the installed PC from a checkout; no Flatpak is involved.
set -euo pipefail

PROFILES_SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/flatpak/naps2/profiles.xml"
install -D -m 0644 "$PROFILES_SRC" "$HOME/.config/naps2/profiles.xml"
printf 'Installed NAPS2 scan profiles for the native RPM: %s\n' "$HOME/.config/naps2/profiles.xml"

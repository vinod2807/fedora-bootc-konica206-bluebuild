#!/bin/bash
# Uninstall Flatpaks that now have native RPMs in the image, and that were
# sitting in /var/lib/flatpak from the old labwc image. Flatpak state is NOT
# baked into the bootc image, so this runs on the installed machine once after
# rebooting into the Kinoite build. Kept: OTPClient and Stremio (no RPM).
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Back up and restore the Firefox profile BEFORE --delete-data destroys any
# leftover data. Always call it: the profile may live in ~/.config even when
# the Flatpak is already gone. It aborts on failure, so no Flatpak is removed
# until migration has succeeded.
"$here/migrate-firefox-flatpak-profile.sh"

ids=(
  ai.storyteller.pdfcraft
  com.brave.Browser
  com.mattjakeman.ExtensionManager
  com.naps2.Naps2
  com.usebottles.bottles
  com.xnview.XnViewMP
  de.haeckerfelix.Shortwave
  io.github.troyeguo.koodo-reader
  io.gitlab.adhami3310.Impression
  io.mpv.Mpv
  net.zoite.Zoitechat
  org.gnome.Calculator
  org.gnome.gThumb
  org.gpodder.gpodder
  org.kde.okular
  org.localsend.localsend_app
  org.libreoffice.LibreOffice
  org.mozilla.firefox
  org.onlyoffice.desktopeditors
  org.qbittorrent.qBittorrent
  org.videolan.VLC
  rocks.zapfast.ZapFast
)

# Apps with no native RPM are deliberately kept.
keep=(com.github.paolostivanin.OTPClient com.stremio.Stremio)

for id in "${ids[@]}"; do
  if printf '%s\n' "${keep[@]}" | grep -qx "$id"; then
    printf 'KEEP  %s (no RPM counterpart)\n' "$id"
    continue
  fi
  if flatpak list --app --columns=application | grep -qx "$id"; then
    printf 'REMOVE %s\n' "$id"
    flatpak uninstall --noninteractive --delete-data "$id" || \
      flatpak uninstall --user --noninteractive --delete-data "$id" || \
      sudo flatpak uninstall --noninteractive --delete-data "$id" || true
  else
    printf 'SKIP  %s (not installed)\n' "$id"
  fi
done

printf '\nDone. Remaining Flatpaks:\n'
flatpak list --app --columns=application,name 2>/dev/null || true

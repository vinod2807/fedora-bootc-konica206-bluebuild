#!/usr/bin/env bash
# Apply the Plasma performance tweaks to the CURRENT user session (no reboot
# needed for the service changes). The same tweaks are baked into the image for
# future builds via user.masked units and /etc/skel config defaults.
set -euo pipefail

units=(
  kde-baloo.service
  kde-baloo-idle-monitor.service
  plasma-baloorunner.service
  plasma-kactivitymanagerd.service
  app-org.kde.discover.notifier@autostart.service
)

echo "Stopping and masking background Plasma services:"
for unit in "${units[@]}"; do
    if systemctl --user mask --now "$unit" >/dev/null 2>&1; then
        printf '  masked %s\n' "$unit"
    else
        printf '  skipped %s (not present)\n' "$unit"
    fi
done

if command -v balooctl6 >/dev/null 2>&1; then
    balooctl6 disable >/dev/null 2>&1 || true
fi

# Instant animations and no blur = noticeably lighter compositing on old GPUs.
kwriteconfig6 --file kdeglobals --group KDE --key AnimationDurationFactor 0
kwriteconfig6 --file kwinrc --group Plugins --key blurEnabled false
kwriteconfig6 --file kwinrc --group Effect-Blur --key Enabled false

printf '\nDone. Log out and back in once for the KWin visual changes to fully apply.\n'
printf 'Remaining background services:\n'
systemctl --user list-units --type=service --no-pager 2>/dev/null \
    | grep -iE 'baloo|kactivity|discover' || true

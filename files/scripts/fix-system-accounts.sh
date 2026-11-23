#!/usr/bin/env bash
# Bake consistent account databases into the image.
#
# bootc base images ship the canonical static accounts in /usr/lib/passwd and
# /usr/lib/group, but /etc/passwd and /etc/group in the container only contain
# accounts created explicitly with useradd during the build. At first boot
# `bootc internals sysusers-sync` then prunes matching entries from
# /etc/shadow and /etc/gshadow, and systemd-sysusers sees the accounts via
# nss-altfiles and skips adding them to /etc/passwd / /etc/group.
#
# The result is a split-brain account database: PAM cannot find users such as
# plasma-setup/plasmalogin, and desktop autologin fails. Populate all account
# files at build time and keep the canonical copies in sync so a fresh
# deployment starts with a complete, consistent set.
set -euo pipefail

# Create every account declared by the sysusers.d snippets of installed
# packages (video, render, input, plasma-setup, plasmalogin, ...).
systemd-sysusers

for f in passwd group shadow gshadow; do
    [ -f "/etc/$f" ] || continue
    # nss-altfiles reads these canonical copies from /usr/lib.
    [ -f "/usr/lib/$f" ] && cp -f "/etc/$f" "/usr/lib/$f"
    # /usr/etc is the pristine /etc copy used by ostree deployments.
    [ -d "/usr/etc" ] && cp -f "/etc/$f" "/usr/etc/$f"
done

# Sanity check: required for DRM access and the graphical session.
# getent is unreliable inside the build container because nss-altfiles is not
# active there; check the canonical files directly instead.
for g in video render input audio; do
    if ! grep -q "^${g}:" /etc/group /usr/lib/group 2>/dev/null; then
        echo "missing group: $g" >&2
        exit 1
    fi
done

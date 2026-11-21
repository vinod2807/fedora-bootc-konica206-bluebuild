#!/usr/bin/env bash
# Guard: the final image must not contain rpm-ostree. bootc manages the system; packages are
# installed at build time with dnf only. Runs last (right before `bootc container lint`) so it
# also catches anything BlueBuild itself or the base image put there.
set -euo pipefail

has() { rpm -q rpm-ostree >/dev/null 2>&1 || command -v rpm-ostree >/dev/null 2>&1; }

if has; then
    echo "rpm-ostree found in the image; removing it (bootc does not depend on it)"
    rpm -q --whatrequires rpm-ostree 2>/dev/null || true
    dnf -y remove --no-autoremove rpm-ostree rpm-ostree-libs || true
    dnf clean all
fi

if has; then
    echo "ERROR: rpm-ostree is still present in the image" >&2
    rpm -qa | grep -i ostree >&2 || true
    exit 1
fi

# Removal must not have taken the bootc stack with it.
rpm -q bootc bootupd >/dev/null
echo "OK: no rpm-ostree; bootc and bootupd are installed"
echo "ostree-related packages that remain (libostree is bootc's backend):"
rpm -qa | grep -i ostree || true

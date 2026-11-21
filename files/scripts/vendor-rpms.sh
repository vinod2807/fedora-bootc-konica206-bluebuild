#!/usr/bin/env bash
# Vendored RPMs committed under files/local-rpms/ (Epson Printer Utility, sane-ar206).
# Port of the "Epson" RUN steps of the upstream Containerfile.
#
# NAPS2 and ZapFast are NOT installed here any more: upstream moved them to Flatpak
# at runtime (Flatpak's /var/lib/flatpak is not part of a bootc image).
# See extras/scripts/install-naps2-flatpak.
set -euxo pipefail

# Scriptlets are skipped on purpose: the Epson RPM's %post launches the ecbd daemon
# in the foreground, which never returns inside a container build (it would hang).
# ecbd is only needed for USB-attached Epson printers; enable it by hand there:
#   sudo systemctl enable --now ecbd.service
rpmdir=/usr/share/konica206-build/local-rpms
if ls "$rpmdir"/*.rpm >/dev/null 2>&1; then
    # NOTE: sane-ar206 is built for a specific Fedora release (fc44 at the time of writing).
    # If the base moves to a newer major, this install may fail until upstream rebuilds it.
    dnf install -y --setopt=tsflags=noscripts "$rpmdir"/*.rpm
    if [ -f /usr/lib/epson-backend/ecbd.service ]; then
        install -D -m 0644 /usr/lib/epson-backend/ecbd.service \
            /usr/lib/systemd/system/ecbd.service
    fi
else
    echo 'no vendor RPMs in local-rpms, skipping'
fi
rm -rf /usr/share/konica206-build
dnf clean all

# The Epson RPM ships its menu entry inside /opt; expose it to the launcher.
if [ -f /opt/epson-printer-utility/epson-printer-utility.desktop ]; then
    ln -sf /opt/epson-printer-utility/epson-printer-utility.desktop \
           /usr/share/applications/epson-printer-utility.desktop
fi

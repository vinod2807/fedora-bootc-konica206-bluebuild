#!/usr/bin/env bash
# Permissions and sanity checks for the baked Torchio print stack.
set -euxo pipefail

chmod 0755 /usr/local/bin/torchiod /usr/local/bin/torchio \
           /usr/local/bin/ensure-torchio-printers \
           /usr/libexec/torchio-cups-proxy \
           /usr/share/konica225i/Filters/245igdirf
chmod 0644 /usr/lib/systemd/user/torchiod.service \
           /usr/lib/systemd/user/torchio-cups-proxy.service \
           /usr/lib/systemd/user/torchio-setup.service \
           /etc/environment.d/50-torchio.conf \
           /etc/profile.d/torchio.sh \
           /etc/skel/.config/torchio/trust.policy \
           /etc/flatpak/overrides/org.libreoffice.LibreOffice \
           /etc/flatpak/overrides/org.gnome.gThumb \
           /etc/systemd/system/legacy-printer-app.service.d/91-konica225i.conf \
           /etc/cups/ppd/konica206.ppd \
           /usr/share/konica225i/ppd/225igdi.ppd \
           /var/lib/legacy-printer-app/legacy-printer-app.state \
           /var/lib/legacy-printer-app/ppd/225igdi.ppd

chmod 0644 /etc/cups/ppd/*.ppd 2>/dev/null || true

test -x /usr/local/bin/torchiod
test -x /usr/libexec/torchio-cups-proxy

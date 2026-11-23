#!/usr/bin/env bash
# Final assembly, run after the stage output has been copied to /.
# Port of the remaining RUN steps of the original Containerfile.
set -euxo pipefail

# xfce4-panel ships with Thunar's libxfce4panel dependency; hide its Settings
# entries that labwc/sfwbar ignore. The package itself must stay.
rm -f /usr/share/applications/panel-preferences.desktop \
      /usr/share/applications/panel-desktop-handler.desktop

# Dedicated unprivileged account for the printer application. USB access comes
# from the udev rule (group lp, mode 0660), not from running as root.
useradd --system --user-group --no-create-home \
        --home-dir /var/lib/konica206 --shell /usr/sbin/nologin konica
usermod -aG lp konica

# The encoder looks for Konica-owned runtime data at a fixed path under
# /usr/local/lib. /usr is immutable on bootc, so that path is a symlink into
# persistent state; licensed files are installed later by
# konica206-install-vendor-data and are never baked into the image.
install -d -m 0755 /var/lib/konica206/vendor
install -d -m 0755 /usr/local/lib
ln -sTf /var/lib/konica206/vendor /usr/local/lib/konica

# GRUB menu waits 10 s so an older deployment can be picked by hand. bootupd
# concatenates this static config into /boot/grub2/grub.cfg at install time.
cfg=/usr/lib/bootupd/grub2-static/grub-static-pre.cfg
sed -i -E 's/^set timeout=[0-9]+$/set timeout=10/' "$cfg"
grep -qx 'set timeout=10' "$cfg"

chmod 0755 /usr/bin/konica206-native /usr/bin/konica-send /usr/bin/konica-render /usr/bin/konica-native
chmod 0755 /usr/libexec/konica206/install-vendor-data /usr/libexec/konica206/install-vendor-data-onboot \
           /usr/libexec/konica206/ensure-queue /usr/libexec/konica206/preflight \
           /usr/libexec/konica206/ensure-legacy-queue /usr/libexec/konica206/ensure-classic-queue \
           /usr/libexec/konica206/pdf-duplex-shim \
           /usr/libexec/epson-l3260/ensure-queue \
           /usr/libexec/setup-samba
chmod 0755 /usr/local/bin/konica-cups-watch.sh /usr/local/bin/fuzzel-printjobs \
           /usr/local/bin/konica-scan \
           /usr/local/sbin/check-wineps-route.sh \
           /usr/local/libexec/konica-backend/usb
chmod 0755 /etc/xdg/labwc/autostart
chmod 0644 /etc/greetd/config.toml /etc/pam.d/greetd /etc/systemd/zram-generator.conf \
    /etc/modprobe.d/90-konica206-usblp.conf /etc/samba/smb.conf \
    /etc/flatpak/overrides/com.stremio.Stremio /etc/cups/wineps.convs \
    /etc/xdg/labwc/menu.xml /etc/xdg/labwc/rc.xml \
    /etc/systemd/system/legacy-printer-app.service.d/90-konica206uri.conf \
    /usr/lib/systemd/system/konica206-native.service \
    /usr/lib/systemd/system/konica206-queue.service \
    /usr/lib/systemd/system/epson-l3260-queue.service \
    /usr/lib/systemd/system/samba-setup.service \
    /usr/lib/systemd/system/konica206-vendor-data.service \
    /usr/lib/systemd/system/konica206-classic-queue.service \
    /etc/konica206/vendor-data.conf \
    /usr/lib/systemd/system/nmb.service.d/10-wait-for-interface.conf \
    /usr/lib/systemd/system/bootc-upgrade.service \
    /usr/lib/systemd/system/bootc-upgrade.timer \
    /usr/lib/systemd/system/flatpak-update.service \
    /usr/lib/systemd/system/flatpak-update.timer \
    /usr/lib/systemd/user/flatpak-update.service \
    /usr/lib/systemd/user/flatpak-update.timer \
    /usr/lib/systemd/system/konica-cups-watch.service \
    /usr/lib/systemd/system/konica-cups-watch.timer \
    /usr/lib/systemd/system/konica206uri-queue.service \
    /usr/lib/tmpfiles.d/konica206uri.conf \
    /usr/lib/udev/rules.d/70-konica206.rules \
    /usr/lib/udev/rules.d/71-konica206-usb-presence.rules \
    /usr/local/share/konica-retrofit/min-ar.ps \
    /usr/share/konica206/retrofit-commit \
    /usr/share/konica206/legacy-ppd/KonicaMinolta-206-fullbleed.ppd \
    /usr/share/sfwbar/sfwbar.config \
    /usr/share/applications/konica206-reboot.desktop \
    /usr/share/applications/konica206-poweroff.desktop \
    /usr/share/applications/weechat.desktop \
    /usr/share/applications/fuzzel-printjobs.desktop \
    /usr/share/applications/konica-scan.desktop \
    /usr/share/ppd/konica206/konica206.ppd \
    /usr/share/ppd/konica206/konica206-classic.ppd \
    /usr/share/konica206/ppd/KonicaMinolta-206-native-normal.ppd

# konica206-app.ppd = konica206.ppd + the PDF duplex shim filter (upstream: docs/DUPLEX-BACKSIDE.md).
shim_line='*cupsFilter2: "application/pdf image/urf 5 /usr/libexec/konica206/pdf-duplex-shim"'
{ cat /usr/share/ppd/konica206/konica206.ppd; printf '\n%s\n' "$shim_line"; } \
    > /usr/share/ppd/konica206/konica206-app.ppd
chmod 0644 /usr/share/ppd/konica206/konica206-app.ppd
grep -qxF "$shim_line" /usr/share/ppd/konica206/konica206-app.ppd

update-desktop-database /usr/share/applications
ln -sf /usr/libexec/konica206/install-vendor-data /usr/bin/konica206-install-vendor-data
ln -sf /usr/libexec/konica206/preflight /usr/bin/konica206-preflight
install -d -m 0755 /usr/share/konica206

# --- labwc desktop integration -------------------------------------------------
# System-wide dconf defaults (dark mode etc.) from /etc/dconf/db/local.d.
dconf update
# Default-app IDs in /etc/xdg/mimeapps.list must match installed .desktop files;
# a wrong ID silently falls back to "ask". Warn (do not fail the build) if any is missing.
for id in $(sed -n 's/^[^#=]*=\(.*\.desktop\)$/\1/p' /etc/xdg/mimeapps.list | sort -u); do
    if [ ! -e "/usr/share/applications/$id" ]; then
        echo "WARNING: mimeapps.list references missing /usr/share/applications/$id" >&2
    fi
done
# Portal routing file must match XDG_CURRENT_DESKTOP from /etc/xdg/labwc/environment.
test -f /etc/xdg/xdg-desktop-portal/labwc-portals.conf
grep -qx 'XDG_CURRENT_DESKTOP=labwc' /etc/xdg/labwc/environment

# Enable CUPS printer sharing at build time instead of at boot (a boot-time
# `cupsctl --share-printers` makes cupsd restart and log a spurious failure).
conf=/etc/cups/cupsd.conf
test -f "$conf"
sed -i -E \
    -e 's/^[[:space:]]*Browsing[[:space:]].*/Browsing On/' \
    -e 's/^[[:space:]]*BrowseLocalProtocols[[:space:]].*/BrowseLocalProtocols dnssd/' \
    -e '/^[[:space:]]*Listen[[:space:]]+localhost:631[[:space:]]*$/d' \
    "$conf"
grep -qE '^[[:space:]]*Browsing[[:space:]]+On[[:space:]]*$' "$conf" || \
    printf '\nBrowsing On\n' >> "$conf"
grep -qE '^[[:space:]]*BrowseLocalProtocols[[:space:]]+.*dnssd' "$conf" || \
    printf 'BrowseLocalProtocols dnssd\n' >> "$conf"
grep -qE '^[[:space:]]*Port[[:space:]]+631[[:space:]]*$' "$conf" || \
    printf 'Port 631\n' >> "$conf"
if ! sed -n '/^<Location \/>$/,/^<\/Location>$/p' "$conf" | grep -qx '[[:space:]]*Allow @LOCAL'; then
    sed -i '/^<Location \/>$/,/^<\/Location>$/ s/^[[:space:]]*Order allow,deny[[:space:]]*$/  Order allow,deny\n  Allow @LOCAL/' "$conf"
fi
grep -qE '^[[:space:]]*Browsing[[:space:]]+On[[:space:]]*$' "$conf"
grep -qE '^[[:space:]]*BrowseLocalProtocols[[:space:]]+.*dnssd' "$conf"
grep -qE '^[[:space:]]*Port[[:space:]]+631[[:space:]]*$' "$conf"
sed -n '/^<Location \/>$/,/^<\/Location>$/p' "$conf" | grep -qx '[[:space:]]*Allow @LOCAL'

# Flathub as a system remote out of the box (flatpak imports remotes.d on first run).
install -d -m 0755 /etc/flatpak/remotes.d
curl --retry 3 --retry-delay 5 -fsSL \
    -o /etc/flatpak/remotes.d/flathub.flatpakrepo \
    https://dl.flathub.org/repo/flathub.flatpakrepo

# Graphical login by default (greetd on VT1 -> tuigreet -> labwc).
systemctl set-default graphical.target
rm -f /etc/systemd/system/timers.target.wants/bootc-fetch-apply-updates.timer
if [ -e /usr/lib/systemd/system/ecbd.service ]; then
    systemctl enable ecbd.service
fi

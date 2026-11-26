#!/usr/bin/env bash
# Re-import the PRINTER / SYSTEM side of vinod2807/fedora-bootc-konica206 into files/.
#
#   tools/import-from-source.sh [path-to-source-checkout]
#
# With no argument the source repo is cloned into a temp directory.
#
# Deliberately NOT imported (this repo owns them; upstream moved to Cinnamon,
# this image stays on MATE on Xorg with LightDM):
#   etc/lightdm/*, usr/lib/tmpfiles.d/50-mate-lightdm.conf,
#   usr/share/applications/mate-printjobs.desktop, mate-printjobs,
#   MATE portal/theme/mime defaults, konica206-{reboot,poweroff}.desktop.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
src="${1:-}"
if [ -z "$src" ]; then
    src="$(mktemp -d)/src"
    git clone --depth 1 https://github.com/vinod2807/fedora-bootc-konica206 "$src"
fi
[ -f "$src/Containerfile" ] || { echo "not a source checkout: $src" >&2; exit 1; }
echo "importing from $(git -C "$src" rev-parse HEAD 2>/dev/null || echo '?')"

sys="$here/files/system"
missing=0

put() { # source-relative-path  destination-under-files/system  mode
    if [ ! -f "$src/$1" ]; then echo "MISSING: $1" >&2; missing=1; return; fi
    install -D -m "$3" "$src/$1" "$sys/$2"
}

# --- bootc / kernel args / modprobe ---
put bootc/90-linux-pc-crash-fixes.toml        usr/lib/bootc/kargs.d/90-linux-pc-crash-fixes.toml 0644
put modprobe.d/90-linux-pc-crash-fixes.conf   etc/modprobe.d/90-linux-pc-crash-fixes.conf 0644
put modprobe.d/90-konica206-usblp.conf        etc/modprobe.d/90-konica206-usblp.conf 0644

# --- systemd units ---
for u in konica206-native.service konica206-queue.service epson-l3260-queue.service \
         konica206-classic-queue.service konica206-vendor-data.service samba-setup.service \
         bootc-upgrade.service bootc-upgrade.timer \
         flatpak-update.service flatpak-update.timer; do
    put "systemd/$u" "usr/lib/systemd/system/$u" 0644
done
put systemd/nmb.service.d/10-wait-for-interface.conf \
    usr/lib/systemd/system/nmb.service.d/10-wait-for-interface.conf 0644
put systemd/user/flatpak-update.service usr/lib/systemd/user/flatpak-update.service 0644
put systemd/user/flatpak-update.timer   usr/lib/systemd/user/flatpak-update.timer 0644
put systemd/zram-generator.conf         etc/systemd/zram-generator.conf 0644
put systemd/zram-setup-no-fail-on-stop.conf \
    usr/lib/systemd/system/systemd-zram-setup@zram0.service.d/10-no-fail-on-stop.conf 0644
# Source for the licensed vendor data (a path/URL, not the data itself).
put systemd/konica206-vendor-data.conf  etc/konica206/vendor-data.conf 0644

# --- udev ---
put udev/70-konica206.rules    usr/lib/udev/rules.d/70-konica206.rules 0644

# --- scripts ---
put scripts/install-vendor-data   usr/libexec/konica206/install-vendor-data 0755
put scripts/konica-vendor-data-boot usr/libexec/konica206/install-vendor-data-onboot 0755
put scripts/ensure-queue          usr/libexec/konica206/ensure-queue 0755
put scripts/preflight             usr/libexec/konica206/preflight 0755
put scripts/ensure-classic-queue  usr/libexec/konica206/ensure-classic-queue 0755
put scripts/pdf-duplex-shim       usr/libexec/konica206/pdf-duplex-shim 0755
put scripts/ensure-epson-queue    usr/libexec/epson-l3260/ensure-queue 0755
put scripts/setup-samba           usr/libexec/setup-samba 0755
# fuzzel-printjobs is replaced by this repo's zenity-based mate-printjobs
# (files/stage-inputs/mate-printjobs), installed by build-konica-stage.sh.
put scripts/konica-scan           usr/local/bin/konica-scan 0755

# --- samba, flatpak overrides, PPDs ---
put samba/smb.conf                etc/samba/smb.conf 0644
put flatpak/overrides/com.stremio.Stremio etc/flatpak/overrides/com.stremio.Stremio 0644
put ppd/konica206.ppd             usr/share/ppd/konica206/konica206.ppd 0644
put ppd/konica206-classic.ppd     usr/share/ppd/konica206/konica206-classic.ppd 0644
# konica206-app.ppd is generated at build time (see files/scripts/konica-final.sh).

# --- printing / scanning launchers (desktop-neutral; mpv.desktop is skipped: mpv is a Flatpak) ---
# The Print Jobs launcher is repo-owned (usr/share/applications/mate-printjobs.desktop).
put desktop/applications/konica-scan.desktop      usr/share/applications/konica-scan.desktop 0644
put desktop/applications/weechat.desktop          usr/share/applications/weechat.desktop 0644
# Upstream launches WeeChat in QTerminal; this image uses MATE Terminal.
sed -i 's/^Exec=qterminal -e weechat/Exec=mate-terminal -e weechat/' \
    "$here/files/system/usr/share/applications/weechat.desktop"

# --- inputs consumed by the konica-build stage (assembled/patched there) ---
stage="$here/files/stage-inputs"
sput() { # source-relative-path  name-in-stage-inputs  mode
    if [ ! -f "$src/$1" ]; then echo "MISSING: $1" >&2; missing=1; return; fi
    install -D -m "$3" "$src/$1" "$stage/$2"
}
sput cups/wineps.convs                                   wineps.convs 0644
sput udev/71-konica206-usb-presence.rules                71-konica206-usb-presence.rules 0644
sput scripts/ensure-legacy-queue                         ensure-legacy-queue 0755
sput systemd/konica206uri-queue.service                  konica206uri-queue.service 0644
sput systemd/legacy-printer-app.service.d/90-konica206uri.conf 90-konica206uri.conf 0644
sput systemd/tmpfiles.d/konica206uri.conf                konica206uri.tmpfiles.conf 0644

# --- vendored RPMs (Epson Printer Utility, sane-ar206) + README ---
rm -rf "$here/files/local-rpms"
if compgen -G "$src/local-rpms/*" >/dev/null; then
    mkdir -p "$here/files/local-rpms"
    cp -a "$src"/local-rpms/. "$here/files/local-rpms/"
fi

# --- NAPS2 is a runtime Flatpak on the installed machine, not part of the image.
#     Kept here (same relative layout the script expects) so you can run it from a checkout.
install -D -m 0755 "$src/scripts/install-naps2-flatpak" "$here/extras/scripts/install-naps2-flatpak"
install -D -m 0644 "$src/flatpak/naps2/profiles.xml"    "$here/extras/flatpak/naps2/profiles.xml"

# --- docs and the tested BIOS ISO pipeline (reads GITHUB_REPOSITORY, so it
#     automatically targets this repo's GHCR image) ---
rm -rf "$here/docs"; mkdir -p "$here/docs" "$here/.github/iso" "$here/.github/workflows"
cp -a "$src"/docs/. "$here/docs/"
# This repo swapped the labwc launcher for the MATE one; keep the doc accurate
# across re-imports instead of letting upstream's path come back.
sed -i 's#`/usr/local/bin/fuzzel-printjobs` (launcher + `W-e` keybind)#`/usr/local/bin/mate-printjobs` (MATE app menu, zenity picker)#' \
    "$here/docs/PRINTER.md"
cp -a "$src/.github/iso/." "$here/.github/iso/"
cp -a "$src/.github/workflows/build-iso.yml" "$here/.github/workflows/build-iso.yml"

if [ "$missing" -ne 0 ]; then
    echo "Some source files were missing (see above)." >&2
    exit 2
fi
echo "Imported OK into $here/files"

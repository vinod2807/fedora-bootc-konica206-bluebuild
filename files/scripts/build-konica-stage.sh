#!/usr/bin/env bash
# Runs inside the `konica-build` stage (a plain Fedora container).
# Port of the `printer-builder` stage of the original Containerfile.
# Output: /out/ is an overlay laid out exactly as it must appear in the final image.
set -euxo pipefail

KONICA_APP_REPO="${KONICA_APP_REPO:-https://github.com/vinod2807/konica206-native-alpine.git}"
KONICA_NATIVE_REPO="${KONICA_NATIVE_REPO:-https://github.com/vinod2807/konica-native-musl.git}"
KONICA_RETROFIT_REPO="${KONICA_RETROFIT_REPO:-https://github.com/vinod2807/konica-retrofit.git}"
# Default to upstream main (resolved to a SHA below and recorded in the image).
# Set these to a commit SHA to pin.
KONICA_APP_REF="${KONICA_APP_REF:-main}"
KONICA_NATIVE_REF="${KONICA_NATIVE_REF:-main}"
KONICA_RETROFIT_REF="${KONICA_RETROFIT_REF:-main}"

IN=/usr/src/stage-inputs
export LANG=C.UTF-8

# util-linux provides runuser (needed by the non-root check-native test).
dnf install -y --setopt=install_weak_deps=False \
    ca-certificates cups-devel gcc ghostscript git libusb1-devel make \
    pappl-devel pkgconf-pkg-config findutils diffutils python3 util-linux
dnf clean all

mkdir -p /src
cd /src

clone_at() { # name repo ref
    git clone --depth 1 "$2" "$1"
    git -C "$1" fetch --depth 1 origin "$3"
    git -C "$1" checkout --detach FETCH_HEAD
}
clone_at app      "$KONICA_APP_REPO"      "$KONICA_APP_REF"
clone_at native   "$KONICA_NATIVE_REPO"   "$KONICA_NATIVE_REF"
clone_at retrofit "$KONICA_RETROFIT_REPO" "$KONICA_RETROFIT_REF"

root=/out
install -d "$root/etc/cups" \
           "$root/etc/systemd/system/legacy-printer-app.service.d" \
           "$root/usr/bin" \
           "$root/usr/local/bin" \
           "$root/usr/local/sbin" \
           "$root/usr/local/libexec/konica-backend" \
           "$root/usr/local/share/konica-retrofit" \
           "$root/usr/lib/systemd/system" \
           "$root/usr/lib/tmpfiles.d" \
           "$root/usr/lib/udev/rules.d" \
           "$root/usr/libexec/konica206" \
           "$root/usr/share/konica206/legacy-ppd"

# Traceability: source SHAs travel with the image.
git -C app      rev-parse HEAD > "$root/usr/share/konica206/app-commit"
git -C native   rev-parse HEAD > "$root/usr/share/konica206/native-commit"
git -C retrofit rev-parse HEAD > "$root/usr/share/konica206/retrofit-commit"
chmod 0644 "$root"/usr/share/konica206/*-commit
{
    echo "## Printer source commits"
    echo "- app:      $(cat "$root/usr/share/konica206/app-commit")"
    echo "- native:   $(cat "$root/usr/share/konica206/native-commit")"
    echo "- retrofit: $(cat "$root/usr/share/konica206/retrofit-commit")"
} | tee /out/.source-commits.md
rm -f /out/.source-commits.md   # only echoed to the build log

# --- konica-retrofit assets (patched exactly as in the original) -------------
sed 's/^QUEUES="konica206uri konica206uri-ppd"$/QUEUES="konica206 konica206uri konica206uri-ppd"/' \
    retrofit/konica-cups-watch.sh > "$root/usr/local/bin/konica-cups-watch.sh"
grep -qx 'QUEUES="konica206 konica206uri konica206uri-ppd"' \
    "$root/usr/local/bin/konica-cups-watch.sh"
sed 's#/etc/cups/ppd/konica206uri.ppd#/etc/cups/ppd/konica206.ppd#' \
    retrofit/check-wineps-route.sh > "$root/usr/local/sbin/check-wineps-route.sh"
grep -q '/etc/cups/ppd/konica206.ppd' "$root/usr/local/sbin/check-wineps-route.sh"
chmod 0755 "$root/usr/local/bin/konica-cups-watch.sh" \
           "$root/usr/local/sbin/check-wineps-route.sh"
# The two desktop helpers must ship in the stage output: the final image gets
# /usr/local/bin from `COPY --from=konica-build --link /out/ /`, which replaces
# anything copied there by an earlier files module.
install -m 0755 "$IN/mate-printjobs" "$IN/konica-scan" "$root/usr/local/bin/"

install -m 0644 retrofit/tests/min-ar.ps "$root/usr/local/share/konica-retrofit/min-ar.ps"
install -m 0644 retrofit/konica-cups-watch.service retrofit/konica-cups-watch.timer \
    "$root/usr/lib/systemd/system/"
install -m 0644 "$IN/wineps.convs" "$root/etc/cups/wineps.convs"
install -m 0644 "$IN/71-konica206-usb-presence.rules" \
    "$root/usr/lib/udev/rules.d/71-konica206-usb-presence.rules"
install -m 0755 "$IN/ensure-legacy-queue" "$root/usr/libexec/konica206/ensure-legacy-queue"
install -m 0644 "$IN/konica206uri-queue.service" \
    "$root/usr/lib/systemd/system/konica206uri-queue.service"
install -m 0644 "$IN/90-konica206uri.conf" \
    "$root/etc/systemd/system/legacy-printer-app.service.d/90-konica206uri.conf"
install -m 0644 "$IN/konica206uri.tmpfiles.conf" \
    "$root/usr/lib/tmpfiles.d/konica206uri.conf"

ppd="$root/usr/share/konica206/legacy-ppd/KonicaMinolta-206-fullbleed.ppd"
sed -e 's#^\*cupsFilter: .*#*cupsFilter: "application/vnd.cups-raster 0 /usr/bin/konica-native"#' \
    -e 's#^\*DefaultDuplex:.*#*DefaultDuplex: None#' \
    -e 's#^\*cupsManualCopies:.*#*cupsManualCopies: True#' \
    -e 's#^\*cupsBackSide:.*#*cupsBackSide: Rotated#' \
    -e '/^\*OCM_resourceDir:/d' \
    retrofit/backup/var/lib/legacy-printer-app/ppd/KonicaMinolta-206-fullbleed.ppd > "$ppd"
grep -qxF '*cupsFilter: "application/vnd.cups-raster 0 /usr/bin/konica-native"' "$ppd"
grep -qxF '*DefaultDuplex: None' "$ppd"
grep -qxF '*cupsBackSide: Rotated' "$ppd"
! grep -q '^\*OCM_resourceDir:' "$ppd"
# Rotated-backside variant (upstream: docs/DUPLEX-BACKSIDE.md).
install -d -m 0755 "$root/usr/share/konica206/ppd"
cp "$ppd" "$root/usr/share/konica206/ppd/KonicaMinolta-206-fullbleed-rotated.ppd"
grep -qxF '*cupsBackSide: Rotated' "$root/usr/share/konica206/ppd/KonicaMinolta-206-fullbleed-rotated.ppd"
# Normal-backside copy for the PAPPL app's builtin renderer (upstream
# konica206-native-alpine 30c0739): CUPS/legacy PPDs keep Rotated, but the
# 206's duplexer binds long edge itself, so the app must not pre-rotate backs.
sed 's/^\*cupsBackSide:.*/*cupsBackSide: Normal/' "$ppd" \
    > "$root/usr/share/konica206/ppd/KonicaMinolta-206-native-normal.ppd"
grep -qxF '*cupsBackSide: Normal' "$root/usr/share/konica206/ppd/KonicaMinolta-206-native-normal.ppd"

gcc -O2 -std=gnu17 -Wall -Wextra \
    -o "$root/usr/local/libexec/konica-backend/usb" \
    retrofit/backup/source/konica-usb-backend/konica-usb-backend.c \
    $(pkg-config --cflags --libs libusb-1.0)
chmod 0755 "$root/usr/local/libexec/konica-backend/usb"
test -x "$root/usr/local/libexec/konica-backend/usb"

# --- Upstream tests (need no printer, USB device or vendor data) --------------
# A failure here fails the whole image build, so nothing gets published.
make -C /src/app -j"$(nproc)"
make -C /src/app check

# check-native must not run as root (root would use the real service's PAPPL state).
useradd --create-home --shell /bin/bash tester
runuser -u tester -- env HOME=/home/tester make -C /src/app check-native

make -C /src/native -j"$(nproc)"
make -C /src/native check

# --- Collect only the binaries; the upstream clone (with its vendor/ tree) never ships ---
install -D -m 0755 /src/app/konica206-native /out/usr/bin/konica206-native
install -D -m 0755 /src/app/konica-send      /out/usr/bin/konica-send
install -D -m 0755 /src/app/konica-render    /out/usr/bin/konica-render
install -D -m 0755 /src/native/konica-native /out/usr/bin/konica-native

find /out -type f | sort

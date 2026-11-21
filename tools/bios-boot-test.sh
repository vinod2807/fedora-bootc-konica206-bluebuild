#!/usr/bin/env bash
# Install a bootc image onto a virtual disk and boot it under SeaBIOS.
#
#   sudo tools/bios-boot-test.sh ghcr.io/<owner>/fedora-bootc-konica206-bluebuild:latest
#
# Needs: podman, qemu-system-x86_64, sfdisk. Writes ./bios-boot-serial.log.
# PASS = the installed disk has a BIOS-boot partition AND SeaBIOS boots it to a
# serial login prompt. It proves the BIOS bootloader path, not your PC's firmware.
set -euo pipefail

image="${1:?usage: $0 <image-ref>}"
size="${DISK_SIZE:-24G}"
work="$(mktemp -d)"
log="$PWD/bios-boot-serial.log"
trap 'rm -rf "$work"' EXIT

podman pull "$image"
truncate -s "$size" "$work/disk.img"

podman run --rm --privileged --pid=host \
    -v /dev:/dev -v /var/lib/containers:/var/lib/containers -v "$work":/out \
    --security-opt label=type:unconfined_t \
    "$image" \
    bootc install to-disk --via-loopback --wipe \
        --filesystem ext4 \
        --karg console=ttyS0,115200 --karg console=tty0 \
        /out/disk.img

echo "--- partition table ---"
sfdisk -d "$work/disk.img" | tee "$work/pt.txt"
# GPT type GUID for "BIOS boot" is 21686148-6449-6E6F-744E-656564454649
grep -qi '21686148-6449-6E6F-744E-656564454649' "$work/pt.txt" \
    || { echo "FAIL: no BIOS boot partition on the installed disk" >&2; exit 1; }

accel=tcg
[ -w /dev/kvm ] && accel=kvm
echo "--- booting under SeaBIOS (accel=$accel) ---"
# No -bios/OVMF flag: QEMU's default firmware is SeaBIOS (legacy BIOS).
set +e
timeout "${BOOT_TIMEOUT:-900}" qemu-system-x86_64 \
    -accel "$accel" -m 3G -smp 2 -nographic -serial "file:$log" -monitor none \
    -drive file="$work/disk.img",format=raw,if=ide &
qpid=$!
for _ in $(seq 1 "${BOOT_TIMEOUT:-900}"); do
    if grep -qE 'login:' "$log" 2>/dev/null; then
        kill "$qpid" 2>/dev/null; wait "$qpid" 2>/dev/null
        echo "PASS: reached a login prompt under SeaBIOS"
        exit 0
    fi
    kill -0 "$qpid" 2>/dev/null || break
    sleep 1
done
kill "$qpid" 2>/dev/null
echo "FAIL: no login prompt; last serial output:" >&2
tail -n 40 "$log" >&2 || true
exit 1

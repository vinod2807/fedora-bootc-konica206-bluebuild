# fedora-bootc-konica206-bluebuild

BlueBuild port of [`vinod2807/fedora-bootc-konica206`](https://github.com/vinod2807/fedora-bootc-konica206),
**MATE/Xorg edition**: Fedora bootc, MATE on Xorg with LightDM (`lightdm-gtk` greeter, autologin as
`vinod`), Konica Minolta bizhub 206 (PAPPL + native C11 encoder + legacy `konica206uri` queues),
Epson L3260 driverless queue, Samba.

Published image: `ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest`

Base image lineage (verified from the published image's OCI labels — see "Base image" below):

```
ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest
  └── ghcr.io/blue-build/base-images/fedora-base:latest
        └── quay.io/fedora-ostree-desktops/base-atomic:45
```

`quay.io/fedora/fedora-bootc:latest` is the base used by the **original** Containerfile
repo; this BlueBuild image does **not** use it.

> **Status: built, published and running on the target PC.** The GHCR image is produced by
> the weekly BlueBuild workflow; the installed system tracks `:latest` and the stage-only
> timer stages updates without rebooting on its own. Legacy-BIOS boot is already proven on
> the target i5-650, so no QEMU boot test runs on every build. The original repo is untouched.

## What tracks upstream and what this repo owns

Imported from upstream commit `98ffb65` (2026-11-19) by `tools/import-from-source.sh`:
printer stack, queue scripts and services, `pdf-duplex-shim` + `konica206-app.ppd`, rotated-backside PPD,
`konica206-vendor-data.service`, `konica206-classic.ppd`, Samba, bootc kargs, update timers, docs, the BIOS ISO pipeline.

**Deliberately not taken from upstream:** the move to **Cinnamon** (and the earlier GNOME/detours).
This image uses **MATE on Xorg with LightDM**. `tools/import-from-source.sh` never touches the desktop
files below, so re-importing cannot bring Cinnamon back. The old labwc/XFCE/LXQt shells
(labwc, sfwbar, Foot, fuzzel, Miriway, PCManFM-Qt, Thunar, mousepad, xarchiver, …
and their configs) are removed from the recipe and the image.

Owned by this repo (desktop): `etc/lightdm/*`, `usr/lib/tmpfiles.d/50-mate-lightdm.conf`,
`usr/share/applications/mate-printjobs.desktop`, `konica206-{reboot,poweroff}.desktop`,
plus the integration files added in this port (below).

## Desktop integration (MATE on Xorg + LightDM)

`lightdm.service` starts the GTK greeter and autologins as `vinod`, launching the packaged
`mate.desktop` session (`mate-session` + Marco + `mate-panel`) on Xorg. This is the supported
MATE session on Fedora: MATE has no production Wayland session, and Polo (a third-party
Wayland compositor released Nov 2026) is not packaged in Fedora and needs Wayland-enabled
rebuilds of packages such as `mate-panel`.

Added or fixed in this port:

| What | Where |
|---|---|
| MATE on Xorg, LightDM GTK greeter and autologin as `vinod` | recipe (`lightdm`, `lightdm-gtk`, `xorg-x11-server-Xorg`) + `etc/lightdm/lightdm.conf.d/90-konica-mate-autologin.conf` |
| `pam_selinux ... open nottys` fix so autologin gets a user context instead of `xdm_t` | `files/scripts/konica-final.sh` (patch of packaged `/usr/lib/pam.d/lightdm-autologin`) |
| Greeter runtime dirs recreated/relabelled at boot (bootc images have no SELinux xattrs) | `usr/lib/tmpfiles.d/50-mate-lightdm.conf` |
| Portal routing for `XDG_CURRENT_DESKTOP=MATE`: GTK portal (file chooser, **print dialog**, dark-mode setting) | `etc/xdg/xdg-desktop-portal/mate-portals.conf` |
| System-wide dark theme defaults for GTK3/GTK4/dconf and MATE (no autostart race) | `etc/gtk-3.0`, `etc/gtk-4.0`, `etc/dconf/{profile,db/local.d/00-mate-defaults}` + `dconf update` at build |
| MATE default applications (folders, PDF, images, text, archives) | `etc/xdg/mimeapps.list` (build warns if an ID does not exist) |
| MATE apps: Caja, Pluma, Atril, Eog, Engrampa, MATE Terminal | recipe |
| Printer GUI + zenity-based print-job tooling | `system-config-printer`, `mate-printjobs`, `konica-scan` desktop entries |
| `wireplumber` explicit (as upstream now does) | recipe |
| Keyring manager (Passwords and Keys) for the gnome-keyring secrets store | `seahorse`, entry in the Settings menu |

Not added on purpose: Bluetooth, a second Wayland session, `mate-screensaver`, and screen
locker/suspend (lock/suspend are intentionally absent on this Ironlake PC).

## Base image

The final image is built from `ghcr.io/blue-build/base-images/fedora-base:latest`, set in
`recipes/recipe.yml` by `base-image: ghcr.io/blue-build/base-images/fedora-base` plus
`image-version: latest`. That base image's own parent is
`quay.io/fedora-ostree-desktops/base-atomic:45`. The `FROM` chain of the published image,
read from its OCI labels, is therefore:

| Image | Evidence |
|---|---|
| `ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest` | installed/tracked image (`bootc status`, `spec.image`) |
| `ghcr.io/blue-build/base-images/fedora-base:latest` | `org.opencontainers.image.base.name` on the published image |
| `quay.io/fedora-ostree-desktops/base-atomic:45` | `org.opencontainers.image.base.name` on `fedora-base` |

`quay.io/fedora/fedora-bootc:latest` appears only in the **original** repo's Containerfile;
it is not the base of this image. The printer **builder stage** does use
`quay.io/fedora/fedora:latest` (a regular Fedora container, via `from:` in `recipe.yml`),
but that is not the bootc base. Verify the current chain at any time with:

```bash
sudo skopeo inspect docker://ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest \
  | grep -E 'base\.(name|digest)'
sudo skopeo inspect docker://ghcr.io/blue-build/base-images/fedora-base:latest \
  | grep -E 'base\.(name|digest)'
```

## No rpm-ostree

The recipe uses only `dnf`/`files`/`script`/`copy`/`systemd`/`signing` modules, never
BlueBuild's `rpm-ostree` module. `files/scripts/no-rpm-ostree.sh` still runs as the last
build step: it removes rpm-ostree if the base ships it, fails the build if it cannot, and
checks `bootc`/`bootupd` survive. `libostree` stays; it is bootc's storage backend, not
rpm-ostree.

## Layout

| Path | What it is |
|---|---|
| `recipes/recipe.yml` | The BlueBuild recipe (base, builder stage, modules, systemd units) |
| `files/system/` | Static assets at final absolute paths, copied to `/` by the `files` module |
| `files/stage-inputs/` | Inputs for the printer builder stage (patched/assembled there) |
| `files/local-rpms/` | Vendored Epson Printer Utility and `sane-ar206` RPMs |
| `files/scripts/build-konica-stage.sh` | Builder stage: clone 3 printer repos, patch retrofit assets (incl. `cupsBackSide: Rotated`), run upstream tests, build binaries, record SHAs |
| `files/scripts/vendor-rpms.sh` | Vendored RPMs (Epson scriptlets skipped) |
| `files/scripts/konica-final.sh` | `konica` user, vendor-data symlink, generated `konica206-app.ppd`, chmods, dconf, cupsd sharing, Flathub remote, GRUB timeout |
| `extras/` | NAPS2 Flatpak installer + scan profiles (run on the installed PC; not part of the image) |
| `docs/` | Upstream printer docs (duplex backside, classic queue, vendor-data permissions, ...) |
| `.github/workflows/build.yml` | BlueBuild action (weekly, push, PR, manual) with chunkah rechunk (64 layers); no automatic BIOS boot test |
| `.github/workflows/build-iso.yml`, `.github/iso/` | Copied from upstream: Anaconda ISO via image-builder `bootc-generic-iso`, El Torito + SeaBIOS checks |
| `tools/import-from-source.sh` | Re-import the printer/system side from upstream |
| `tools/bios-boot-test.sh` | Optional manual check only: install image to a virtual disk, boot under SeaBIOS (not run by CI) |

## First build

1. Create the GitHub repo `fedora-bootc-konica206-bluebuild` and push this tree.
2. Settings → Actions → General → Workflow permissions → **Read and write**.
3. Signing key (no password): `cosign generate-key-pair`; commit `cosign.pub` to the repo root;
   `gh secret set SIGNING_SECRET < cosign.key`. Never commit `cosign.key`.
4. Run **Actions → bluebuild → Run workflow**. Printer tests (`make check`, `check-native` as non-root,
   encoder `make check`) run inside the build; a failure fails the build.
5. After the first push, make the GHCR package **Public**.

## Install on the legacy-BIOS PC

Optional manual check (not part of CI): `sudo tools/bios-boot-test.sh ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest`
on any Linux box with podman + QEMU. The BIOS boot path is already proven on the target
i5-650, so the workflow no longer runs this for every image.

**A. Already on a BIOS bootc install (your i5-650):** keeps the existing bootloader.
```
sudo bootc switch ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest
sudo systemctl reboot
```
Roll back from the 10 s GRUB menu or `sudo bootc rollback`. Check `bootc status` and `cat /proc/cmdline`.
Signature enforcement: see the BlueBuild cosign docs before relying on it.

**B. Fresh install:** run **Actions → build-iso**, write the ISO to USB, boot in legacy BIOS/CSM mode
on wired Ethernet, create your user + root password in Anaconda (LightDM autologins as that user).

After install: `sudo konica206-install-vendor-data <path>` (or set `KONICA_VENDOR_SOURCE` in
`/etc/konica206/vendor-data.conf`; the boot service installs it), `sudo konica206-preflight`, then
`extras/scripts/install-naps2-flatpak` from a checkout for NAPS2.
Updates: `sudo bootc upgrade && sudo systemctl reboot` (the timer only stages).

## Differences from the original, on purpose or not

- **Chunkah rechunk is enabled.** `chunkah: true` with `max_layers: 64` in
  `.github/workflows/build.yml` rechunks the published image into content-based layers,
  like the original repo's chunkah pipeline, so `bootc upgrade` downloads only the layers
  whose content changed. This increases build time and runner disk usage; the action signs
  the rechunked result.
- **No automatic QEMU BIOS boot test.** The post-publish `bios-boot-test` job was removed:
  the image already boots under legacy BIOS on the target PC, and `bootc rollback` covers
  regressions. `tools/bios-boot-test.sh` stays as an optional manual tool;
  `build-iso.yml` still uses QEMU SeaBIOS to check installer ISOs.
- **No container smoke test** (package/unit/no-vendor-files assertions). Only upstream's `make check` tests gate the
  build; the BIOS boot job runs after publish and does not block it.
- **Source SHAs** are stored in `/usr/share/konica206/{app,native,retrofit}-commit` and printed in the build log,
  not in OCI labels or the job summary.
- **Moving refs:** printer repos build from `main` each run. Pin by setting `KONICA_*_REF` to a SHA in
  `files/scripts/build-konica-stage.sh`.
- Fedora release train: the bootc base follows `ghcr.io/blue-build/base-images/fedora-base`
  with `image-version: latest` in `recipes/recipe.yml`; the printer builder stage uses
  `from: quay.io/fedora/fedora:latest`. To freeze, pin `image-version` (e.g. `"45"`) and
  change the stage's `from:` to the same number.
- `mpv.desktop` from upstream is not shipped (mpv is a Flatpak there).
- `etc/konica206/vendor-data.conf` points at `/var/home/vinod/konica-retrofit/...` on your machine.
- `evince` and `gparted` are kept from the earlier image; `gnome-font-viewer` and the Thunar/XFCE
  app stack were dropped in the LXQt swap, and the LXQt/Miriway stack was dropped in the MATE swap.

## Things to verify on the first build

- Base: already verified in the published image — it is based on
  `ghcr.io/blue-build/base-images/fedora-base:latest` (whose parent is
  `quay.io/fedora-ostree-desktops/base-atomic:45`), and the image carries the
  `containers.bootc=1` / `ostree.bootable=true` labels and boots on the target PC.
  `quay.io/fedora/fedora-bootc` is not used here.
- `files/scripts/` location for the `script` module, the `files` module inside a stage, and the `copy` of `/out/`
  into `/` follow the BlueBuild docs but have not been run.
- MATE/LightDM package names (`mate-session-manager`, `mate-panel`, `lightdm`, `lightdm-gtk`,
  `mate-desktop-configs`, `mozo`, `xorg-x11-server-Xorg`, …) were checked against Fedora 45
  before the switch; recheck when the base moves to a newer release. Fedora 45 has no
  `mate-desktop-environment` meta package, so the apps are listed explicitly.
- `sane-ar206` is an **fc44** RPM; if the base moves to Fedora 45 the install may fail until upstream rebuilds it.
- `qt5-qtbase-gui` is kept for the Epson utility (upstream's new package list dropped it).
- Check the build log for `WARNING: mimeapps.list references missing ...` and fix any ID.
- Physical install on the target PC remains the final validation, including a real print.

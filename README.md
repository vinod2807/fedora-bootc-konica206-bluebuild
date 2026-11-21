# fedora-bootc-konica206-bluebuild

BlueBuild port of [`vinod2807/fedora-bootc-konica206`](https://github.com/vinod2807/fedora-bootc-konica206),
**labwc edition**: Fedora bootc, labwc + sfwbar + Foot, greetd/tuigreet, Konica Minolta bizhub 206
(PAPPL + native C11 encoder + legacy `konica206uri` queues), Epson L3260 driverless queue, Samba.

Published image: `ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest`

> **Status: untested draft.** Nothing here has been built or booted yet. Work through
> "First build" and "Things to verify". The original repo is untouched.

## What tracks upstream and what this repo owns

Imported from upstream commit `98ffb65` (2026-11-19) by `tools/import-from-source.sh`:
printer stack, queue scripts and services, `pdf-duplex-shim` + `konica206-app.ppd`, rotated-backside PPD,
`konica206-vendor-data.service`, `konica206-classic.ppd`, Samba, bootc kargs, update timers, docs, the BIOS ISO pipeline.

**Deliberately not taken from upstream:** the move to **Cinnamon + LightDM + Slick Greeter autologin** (and
the earlier GNOME/LXQt detours). This image stays on **labwc + greetd/tuigreet**. `tools/import-from-source.sh`
never touches the desktop files below, so re-importing cannot bring Cinnamon back.

Owned by this repo (desktop): `etc/xdg/labwc/*`, `etc/greetd/*`, `etc/pam.d/greetd`, `usr/share/sfwbar/*`,
`konica206-{reboot,poweroff}.desktop`, plus the integration files added in this port (below).

## Desktop integration (labwc)

Already in the session (`etc/xdg/labwc/autostart`): sfwbar panel, swaybg, mako notifications, udiskie automount,
nm-applet, swayidle (dim only; lock/suspend are intentionally absent on this Ironlake PC), D-Bus activation
environment, gnome-keyring secrets, lxpolkit agent, xdg-user-dirs, Thunar daemon.

Added or fixed in this port:

| What | Where |
|---|---|
| Portal routing for labwc: GTK portal (file chooser, **print dialog**, dark-mode setting) + wlr (screenshot, screen share) | `etc/xdg/xdg-desktop-portal/labwc-portals.conf` |
| System-wide dark theme defaults for GTK3/GTK4/dconf (no autostart race) | `etc/gtk-3.0`, `etc/gtk-4.0`, `etc/dconf/{profile,db/local.d}` + `dconf update` at build |
| Default applications (folders, PDF, images, text, archives) | `etc/xdg/mimeapps.list` (build warns if an ID does not exist) |
| Thumbnails, removable-media and archive integration in Thunar | `tumbler`, `thunar-volman`, `thunar-archive-plugin` |
| Printer GUI + print-job tooling in menus and panel | `system-config-printer`, `fuzzel-printjobs`, `konica-scan` entries in the right-click menu; panel button replaces the dead wallpaper button |
| **Right-click menu was not valid XML** (escaped quote in the Screenshot entry), so labwc could not parse it | fixed in `etc/xdg/labwc/menu.xml` |
| Menu entries pointing at apps that were never installed (`wpg`, `wlsunset` with hard-coded NYC coordinates, `xfce4-power-manager-settings`, `btop`, `baobab`, a no-op "Clipboard History") | removed; NAPS2 entry now runs the Flatpak |
| `wireplumber` explicit (as upstream now does) | recipe |
| Keyring manager (Passwords and Keys) for the gnome-keyring secrets store | `seahorse`, entry in the Settings menu |

Not added on purpose: screen locker (upstream removed `swaylock`), Bluetooth, a graphical greeter.
A graphical greeter (gtkgreet/regreet under cage) is possible later; I did not guess package names for it.

## No rpm-ostree

The base is `quay.io/fedora/fedora-bootc` (a bootc image, not an ostree-native Silverblue/Kinoite one) and the
recipe uses only `dnf`/`files`/`script`/`copy`/`systemd`/`signing` modules, never BlueBuild's `rpm-ostree` module.
Whether the base itself ships the `rpm-ostree` package is unconfirmed, so `files/scripts/no-rpm-ostree.sh` runs as the
last build step: it removes rpm-ostree if present, fails the build if it cannot, and checks `bootc`/`bootupd` survive.
`libostree` stays; it is bootc's storage backend, not rpm-ostree.

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
| `.github/workflows/build.yml` | BlueBuild action (weekly, push, PR, manual) + post-publish BIOS boot test |
| `.github/workflows/build-iso.yml`, `.github/iso/` | Copied from upstream: Anaconda ISO via image-builder `bootc-generic-iso`, El Torito + SeaBIOS checks |
| `tools/import-from-source.sh` | Re-import the printer/system side from upstream |
| `tools/bios-boot-test.sh` | Install image to a virtual disk, boot under SeaBIOS |

## First build

1. Create the GitHub repo `fedora-bootc-konica206-bluebuild` and push this tree.
2. Settings → Actions → General → Workflow permissions → **Read and write**.
3. Signing key (no password): `cosign generate-key-pair`; commit `cosign.pub` to the repo root;
   `gh secret set SIGNING_SECRET < cosign.key`. Never commit `cosign.key`.
4. Run **Actions → bluebuild → Run workflow**. Printer tests (`make check`, `check-native` as non-root,
   encoder `make check`) run inside the build; a failure fails the build.
5. After the first push, make the GHCR package **Public**.

## Install on the legacy-BIOS PC

First run `sudo tools/bios-boot-test.sh ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest`
(or let the workflow do it) on any Linux box with podman + QEMU.

**A. Already on a BIOS bootc install (your i5-650):** keeps the existing bootloader.
```
sudo bootc switch ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest
sudo systemctl reboot
```
Roll back from the 10 s GRUB menu or `sudo bootc rollback`. Check `bootc status` and `cat /proc/cmdline`.
Signature enforcement: see the BlueBuild cosign docs before relying on it.

**B. Fresh install:** run **Actions → build-iso**, write the ISO to USB, boot in legacy BIOS/CSM mode
on wired Ethernet, create your user + root password in Anaconda (greetd/tuigreet logs in as that user).

After install: `sudo konica206-install-vendor-data <path>` (or set `KONICA_VENDOR_SOURCE` in
`/etc/konica206/vendor-data.conf`; the boot service installs it), `sudo konica206-preflight`, then
`extras/scripts/install-naps2-flatpak` from a checkout for NAPS2.
Updates: `sudo bootc upgrade && sudo systemctl reboot` (the timer only stages).

## Differences from the original, on purpose or not

- **No chunkah rechunk pipeline.** The BlueBuild action has an optional `chunkah: true` input; try it only if
  upgrade downloads turn out too large.
- **No container smoke test** (package/unit/no-vendor-files assertions). Only upstream's `make check` tests gate the
  build; the BIOS boot job runs after publish and does not block it.
- **Source SHAs** are stored in `/usr/share/konica206/{app,native,retrofit}-commit` and printed in the build log,
  not in OCI labels or the job summary.
- **Moving refs:** printer repos build from `main` each run. Pin by setting `KONICA_*_REF` to a SHA in
  `files/scripts/build-konica-stage.sh`.
- Fedora release train: `image-version: latest` plus `from: quay.io/fedora/fedora:latest` in the stage.
  Pin both to the same number (e.g. `"44"`) to freeze.
- `mpv.desktop` from upstream is not shipped (mpv is a Flatpak there).
- `etc/konica206/vendor-data.conf` points at `/var/home/vinod/konica-retrofit/...` on your machine.
- Upstream dropped `evince`, `gparted` and `gnome-font-viewer` during its LXQt/GNOME phase; this recipe keeps them
  as in your earlier labwc image. Delete the lines in `recipes/recipe.yml` (and the matching menu entries) if unwanted.

## Things to verify on the first build

- Base: BlueBuild documents other bootc images as usable bases, but `quay.io/fedora/fedora-bootc` as a base is
  untested here. BlueBuild adds files (CLI, nushell, cosign) that `bootc container lint` could object to.
- `files/scripts/` location for the `script` module, the `files` module inside a stage, and the `copy` of `/out/`
  into `/` follow the BlueBuild docs but have not been run.
- Package names added in this port (`tumbler`, `thunar-volman`, `thunar-archive-plugin`, `system-config-printer`,
  `wireplumber`, `dconf`) are standard Fedora names but unchecked against the live repo.
- `sane-ar206` is an **fc44** RPM; if the base moves to Fedora 45 the install may fail until upstream rebuilds it.
- `qt5-qtbase-gui` is kept for the Epson utility (upstream's new package list dropped it).
- Check the build log for `WARNING: mimeapps.list references missing ...` and fix any ID.
- Physical install on the target PC remains the final validation, including a real print.

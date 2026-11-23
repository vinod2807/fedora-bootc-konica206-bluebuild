# fedora-bootc-konica206-bluebuild

BlueBuild port of [`vinod2807/fedora-bootc-konica206`](https://github.com/vinod2807/fedora-bootc-konica206),
**KDE Plasma (Kinoite) edition**: Fedora bootc, Plasma/SDDM from the base, Konica Minolta bizhub 206
(PAPPL + native C11 encoder + legacy `konica206uri` queues), Epson L3260 driverless queue, Samba.
Desktop applications are native RPMs (Fedora, RPM Fusion and vendor RPMs), not Flatpaks.

Published image: `ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest`

Base image lineage (from the recipe; re-verify from OCI labels after the next build):

```
ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest
  └── ghcr.io/blue-build/base-images/fedora-kinoite:latest
        └── quay.io/fedora-ostree-desktops/kinoite:45
```

`quay.io/fedora/fedora-bootc:latest` is the base used by the **original** Containerfile
repo; this BlueBuild image does **not** use it.

> **Status: pending rebuild.** The earlier labwc build was published and running on the
> target PC; this tree switches to Kinoite/Plasma and native RPMs and has not been built yet.
> The weekly BlueBuild workflow publishes `:latest`; the installed system tracks it and the
> stage-only timer stages updates without rebooting on its own. Legacy-BIOS boot was already
> proven on the target i5-650, so no QEMU boot test runs on every build.

## What tracks upstream and what this repo owns

Imported from upstream by `tools/import-from-source.sh`:
printer stack, queue scripts and services, `pdf-duplex-shim` + `konica206-app.ppd`, rotated-backside PPD,
`konica206-vendor-data.service`, `konica206-classic.ppd`, Samba, bootc kargs, update timers, docs, the BIOS ISO pipeline.

**Deliberately not taken from upstream:** any desktop/compositor configuration. Upstream has moved
through GNOME/LXQt/Cinnamon; this image uses Kinoite's Plasma and adds no desktop overrides.
`tools/import-from-source.sh` never imports desktop files, Flatpak overrides for RPM-packaged
apps, or the old NAPS2 Flatpak installer.

Owned by this repo: `recipes/recipe.yml`, build/import/final scripts, the scan launcher, the
vendor-app installer, and printer/Samba/bootc system files.

## Desktop (Kinoite / Plasma)

Everything desktop-related comes from `ghcr.io/blue-build/base-images/fedora-kinoite:latest`:
Plasma, SDDM, Breeze, KDE portals (including the print dialog for GTK/Flatpak apps), KWallet,
PipeWire/WirePlumber, NetworkManager with `plasma-nm`, Dolphin, Okular, Kate, Gwenview, Ark,
Spectacle, KDE Connect and the rest of the KDE app set.

This repo adds **no** compositor, panel, theme, portal, autostart or default-application
overrides. The only desktop-adjacent files it ships are `usr/share/applications/konica-scan.desktop`
(a scanner launcher) and `etc/sddm.conf.d/autologin.conf`, plus the `system-config-printer`
package for CUPS print queues.

### Autologin

`etc/sddm.conf.d/autologin.conf` makes SDDM log in `vinod` automatically into the Plasma
Wayland session. Fedora 45 Kinoite ships that session as `plasma.desktop` (verified with
`dnf repoquery -l plasma-workspace`); the build checks that the file exists. If the installed
account has a different name, edit `User=` in that file on the installed system (or in the
repo before rebuilding). The account must already exist at first boot, otherwise SDDM falls
back to the normal login screen.

### Performance tuning

To keep Plasma responsive on the older i5-650/Ironlake PC, the recipe masks these
user services globally: `kde-baloo.service`, `kde-baloo-idle-monitor.service`
(file indexing), `plasma-baloorunner.service`, `plasma-kactivitymanagerd.service`
(Activities), the startup splash/sound, and the Discover update notifier (updates come
via bootc). KDE Connect is deliberately kept. `etc/sysctl.d/99-plasma-performance.conf`
sets `vm.swappiness=10` and `vm.vfs_cache_pressure=50` to reduce swap churn and keep
the file cache warm.

`files/system/etc/skel/.config/{kdeglobals,kwinrc}` set instant animations and
disable the blur effect for new users; existing users can apply the same changes
immediately with `extras/scripts/tune-plasma-performance.sh` (log out and back in
once for the KWin visual changes to take effect).

### Native RPMs instead of Flatpaks

The old Flatpaks are replaced by native RPMs in the image:

| Former Flatpak | Native RPM / replacement |
|---|---|
| Brave | `brave-browser` (Brave repo) |
| ZapFast | vendor RPM, newest GitHub release resolved at build time |
| NAPS2 | vendor RPM, newest GitHub release resolved at build time |
| XnView MP | vendor RPM (`XnView_MP-linux.x86_64.rpm`) |
| ONLYOFFICE | vendor RPM (`onlyoffice-desktopeditors.x86_64.rpm`) |
| Bottles, gThumb, gPodder, LibreOffice, Firefox, mpv, qBittorrent, VLC, ZoiteChat, GNOME Calculator | same-named Fedora RPMs |
| PdfCraft | `pdfarranger` + Okular |
| Koodo Reader | `calibre` |
| Impression | `flameshot` + Spectacle |
| Shortwave | VLC / mpv |
| LocalSend | KDE Connect (`kdeconnectd`) |
| Extension Manager | not needed on Plasma |

Kept as Flatpaks (no RPM): **OTPClient** and **Stremio**.

`files/scripts/install-vendor-apps.sh` resolves the newest NAPS2/ZapFast release from the GitHub
API on **every build** and installs the vendor RPMs; XnView/ONLYOFFICE use their moving "latest
RPM" URLs. Combined with the weekly workflow and the host's `bootc-upgrade.timer`, these apps
receive automatic updates. `dnf install` on the host is **not** persistent on this image.

After booting into the new image, run `extras/scripts/uninstall-replaced-flatpaks.sh` once to
remove the now-redundant Flatpaks from `/var/lib/flatpak`, then
`extras/scripts/install-naps2-profiles.sh` to restore scan profiles for the native NAPS2 RPM.

## Proprietary media codecs

The recipe enables **RPM Fusion free + nonfree** via the `dnf` module (`repos.nonfree: rpmfusion`)
and installs `gstreamer1-plugins-bad-freeworld`, `gstreamer1-plugins-ugly`, `gstreamer1-libav`,
`libdvdcss`, `libaacs` and `libbdplus`. BlueBuild's Kinoite base also replaces `ffmpeg-free` with
full `ffmpeg` from `fedora-multimedia`, so H.264/H.265/AAC playback works in mpv, VLC and Flatpak
apps. The base removes `ffmpegthumbnailer` (Fedora packaging bug), so some video thumbnails in
Dolphin may be missing.

## Base image

The final image is built from `ghcr.io/blue-build/base-images/fedora-kinoite:latest`, set in
`recipes/recipe.yml` by `base-image: ghcr.io/blue-build/base-images/fedora-kinoite` plus
`image-version: latest`. That base image's own parent is
`quay.io/fedora-ostree-desktops/kinoite:45`. Verify the current chain at any time with:

```bash
sudo skopeo inspect docker://ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest \
  | grep -E 'base\.(name|digest)'
sudo skopeo inspect docker://ghcr.io/blue-build/base-images/fedora-kinoite:latest \
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
| `recipes/recipe.yml` | BlueBuild recipe (Kinoite base, repos, packages, builder stage, systemd units) |
| `files/system/` | Static assets at final absolute paths, copied to `/` by the `files` module |
| `files/stage-inputs/` | Inputs for the printer builder stage (patched/assembled there) |
| `files/local-rpms/` | Vendored Epson Printer Utility and `sane-ar206` RPMs |
| `files/scripts/build-konica-stage.sh` | Builder stage: clone 3 printer repos, patch retrofit assets, run tests, build binaries, record SHAs |
| `files/scripts/vendor-rpms.sh` | Vendored Epson/sane RPMs (Epson scriptlets skipped) |
| `files/scripts/install-vendor-apps.sh` | Installs NAPS2/ZapFast/XnView/ONLYOFFICE RPMs; resolves latest releases on every build |
| `files/scripts/konica-final.sh` | `konica` user, vendor-data symlink, generated `konica206-app.ppd`, chmods, cupsd sharing, Flathub remote, GRUB timeout |
| `extras/scripts/tune-plasma-performance.sh` | Applies runtime Plasma performance tweaks (mask background services, instant animations, no blur) |
| `extras/scripts/migrate-firefox-flatpak-profile.sh` | Backs up the Flatpak Firefox profile and restores it into native Firefox; called by the uninstall script |
| `extras/scripts/uninstall-replaced-flatpaks.sh` | Run on the installed PC: migrates Firefox, then removes Flatpaks now replaced by RPMs |
| `extras/scripts/install-naps2-profiles.sh` | Run on the installed PC: scan profiles for the native NAPS2 RPM |
| `extras/flatpak/naps2/profiles.xml` | Epson/Konica scan profiles |
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
5. Make sure the GHCR package is **Public**.

## Install on the legacy-BIOS PC

Optional manual check (not part of CI): `sudo tools/bios-boot-test.sh ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest`
on any Linux box with podman + QEMU. The BIOS boot path is already proven on the target i5-650.

**A. Already on a BIOS bootc install (your i5-650):** keeps the existing bootloader.
```
sudo bootc switch ghcr.io/vinod2807/fedora-bootc-konica206-bluebuild:latest
sudo systemctl reboot
```
Roll back from the 10 s GRUB menu or `sudo bootc rollback`. Check `bootc status` and `cat /proc/cmdline`.
Signature enforcement: see the BlueBuild cosign docs before relying on it.

**B. Fresh install:** run **Actions → build-iso**, write the ISO to USB, boot in legacy BIOS/CSM mode
on wired Ethernet, create your user + root password in Anaconda — use `vinod` as the username so
SDDM autologin works (Kinoite's SDDM logs in as that user).

After install: `sudo konica206-install-vendor-data <path>` (or set `KONICA_VENDOR_SOURCE` in
`/etc/konica206/vendor-data.conf`; the boot service installs it), `sudo konica206-preflight`, then
`extras/scripts/install-naps2-profiles.sh` and `extras/scripts/uninstall-replaced-flatpaks.sh`
from a checkout (the latter backs up/restores your Flatpak Firefox profile automatically before
deleting Flatpak data; manual backups land in `~/.local/share/konica206/backups/`).
Updates: `sudo bootc upgrade && sudo systemctl reboot` (the timer only stages).

## Differences from the original, on purpose or not

- **Kinoite/Plasma instead of a hand-rolled desktop.** No labwc, greetd, sfwbar, theme, portal or
  default-app files; KDE's own stack is used. Extra GNOME/Xfce apps were dropped as redundant.
- **Native RPMs instead of Flatpaks**, including vendor RPMs with automatic version resolution at build time.
- **RPM Fusion** is enabled for proprietary media codecs.
- **Chunkah rechunk is enabled.** `chunkah: true` with `max_layers: 64` in
  `.github/workflows/build.yml` rechunks the published image into content-based layers,
  so `bootc upgrade` downloads only the layers whose content changed.
- **No automatic QEMU BIOS boot test.** The post-publish `bios-boot-test` job was removed;
  `tools/bios-boot-test.sh` stays as an optional manual tool and `build-iso.yml` still uses
  QEMU SeaBIOS to check installer ISOs.
- **Source SHAs** are stored in `/usr/share/konica206/{app,native,retrofit}-commit` and printed in the build log.
- **Moving refs:** printer repos build from `main` each run. Pin by setting `KONICA_*_REF` to a SHA in
  `files/scripts/build-konica-stage.sh`.
- Fedora release train: the bootc base follows `ghcr.io/blue-build/base-images/fedora-kinoite`
  with `image-version: latest`; the printer builder stage uses `from: quay.io/fedora/fedora:latest`.
- `etc/konica206/vendor-data.conf` points at `/var/home/vinod/konica-retrofit/...` on your machine.

## Things to verify on the first build

- Base/OCI labels: after the new build, confirm `base.name` is `…/fedora-kinoite:latest` whose parent is
  `…/kinoite:45`, and that the image carries `containers.bootc=1` / `ostree.bootable=true`.
- `repos.nonfree: rpmfusion` plus the Brave repo/key: confirm all RPM Fusion and Brave packages install;
  BlueBuild's `common.yml` also uses `negativo17`, and only one nonfree repo can be active at a time.
- `install-vendor-apps.sh`: confirm the GitHub API lookups and all four vendor RPM installs succeed;
  the build log prints each package name/version.
- `sane-ar206` is an **fc44** RPM; if the base moves to Fedora 45 the install may fail until upstream rebuilds it.
- `qt5-qtbase-gui` is kept for the Epson utility.
- Physical install on the target PC remains the final validation, including a real print.

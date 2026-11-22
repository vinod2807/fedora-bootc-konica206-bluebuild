# Torchio print stack (baked into the image)

This image uses **Torchio** as the only system print stack. `cupsd` is masked;
PAPPL printer applications on `127.0.0.1:8000` and `:8001` are the *backends*
that Torchio talks to over IPP.

## Architecture

```
GUI / CLI apps (libcups, lp, GTK/Qt dialogs, Flatpak print portal)
        │  CUPS_SERVER=/run/user/$UID/torchio-proxy/cups.sock
        ▼
CUPS-socket proxy (Python, /usr/libexec/torchio-cups-proxy)
   ├─ GET /printers/NAME.ppd  → serves the real CUPS PPD (GTK duplex)
   └─ POST (IPP)              → forwards to Torchio
        ▼
torchiod (patched v0.1.0, static Go)
   ├─ konica206     → ipp://127.0.0.1:8001/ipp/print/konica206
   │                   native PAPPL app + konica-native encoder → USB 206
   ├─ konica225i    → ipp://127.0.0.1:8000/ipp/print/konica225i
   │                   PAPPL legacy app + vendor 245igdirf filter → USB 206
   └─ EPSON_L3260   → ipps://192.168.1.19/ipp/print
                       direct IPP Everywhere to the network Epson
```

There are only **two physical printers**: the USB Konica Minolta bizhub 206
(VID `132b:232b`, serial `A8A6041029423`) and the Epson L3260 on the LAN.
`konica206` and `konica225i` are two different driver paths to the same USB
device. The "IPP printer" is a process on this machine, not the hardware.

## What is baked into the image

| Path | Purpose |
|---|---|
| `/usr/local/bin/torchiod` | patched static daemon (see *Patches*) |
| `/usr/local/bin/torchio` | stock v0.1.0 client CLI |
| `/usr/local/bin/ensure-torchio-printers` | first-login queue setup (idempotent) |
| `/usr/libexec/torchio-cups-proxy` | CUPS-socket proxy serving the real PPD |
| `/usr/lib/systemd/user/torchiod.service` | per-user daemon |
| `/usr/lib/systemd/user/torchio-cups-proxy.service` | per-user proxy |
| `/usr/lib/systemd/user/torchio-setup.service` | runs the queue setup once |
| `/etc/environment.d/50-torchio.conf` | `CUPS_SERVER` for PAM sessions |
| `/etc/profile.d/torchio.sh` | `CUPS_SERVER` + PATH for login shells |
| `/etc/skel/.config/torchio/trust.policy` | default trust policy for new users |
| `/etc/flatpak/overrides/{org.libreoffice.LibreOffice,org.gnome.gThumb}` | Flatpak `sockets=cups` + sandbox `CUPS_SERVER=/run/cups/cups.sock` |
| `/etc/cups/ppd/konica206.ppd` | PPD served by the proxy for GTK duplex support |
| `/usr/share/torchio/` | bundled `usb-quirks.conf`, `drivers/generic-pcl5.json` |
| `/usr/share/konica225i/` | vendor GDI filter, profiles, halftones, fixed PPD |
| `/var/lib/legacy-printer-app/legacy-printer-app.state` | PAPPL queues + A4 defaults |
| `/var/lib/legacy-printer-app/ppd/225igdi.ppd` | 225i PPD in PAPPL's state PPD dir |
| `/etc/systemd/system/legacy-printer-app.service.d/91-konica225i.conf` | adds the 225i PPD path |

Systemd: `cups.service`, `cups.socket`, `cups.path` are **masked**. The
CUPS queue-creation units (`konica206uri-queue`, `konica-cups-watch*`,
`epson-l3260-queue`, `konica206-classic-queue`) are not enabled.

## Patches applied to Torchio v0.1.0

Source: `github.com/singularityos-lab/torchio`, tag `v0.1.0`
(`e5b7f215f7a3a6e1378b9ea0bd53ebc3e821a878`). Built in a Go 1.26 container
with `CGO_ENABLED=0 go build -buildvcs=false -trimpath -ldflags "-s -w"`.

1. **`internal/queue/actor.go` — `const sendAttempts = 1`**
   Upstream retries transient send failures up to 3 times without checking
   whether the printer already accepted the job. With an Epson that timed out
   after accepting, this produced two physical copies. One attempt means a
   failed job aborts instead of duplicating.

2. **`internal/daemon/daemon.go` — `NewPDFiumTransform(360)`**
   Upstream rendered PWG raster at 300 dpi. The Epson supports 360/720/1440
   dpi and rejected 300-dpi rasters.

3. **`internal/transform/pdfium.go` — scale each rendered page to A4**
   Some applications emit PDFs whose MediaBox is in pixels (e.g.
   `2480x3508pt`). At 360 dpi that became a 12400x17540 raster; the Epson
   rejected it. Pages are now resized to `210mm x 297mm` at the transform DPI.

4. **`internal/transform/pwgraster.go` — PWG header media strings**
   Set `MediaClass = "PwgRaster"` and `MediaType = "Stationery"` like CUPS.
   Some printers reject a header with empty media strings.

Backups of earlier builds are kept on the running host under `/tmp/opencode/`
during the migration; the authoritative artifact is the binary in this repo.

## Konica 225i PPD fixes

The vendor `BH225iGDILinux_201MU.zip` PPD (`225igdi.ppd`) was corrected before
baking:

- `FLS_8D125X13D25`: `ImageableArea` right edge `586` → `584` to match its
  `PaperDimension` width. This removed a `-2 pt` margin that made PAPPL reject
  the driver with the misleading "Printer names must start with..." error.
- All `*ImageableArea` entries changed from full-sheet (`0 0 W H`) to 12 pt
  margins (`12 12 W-12 H-12`), e.g. A4 `0 0 595 842` → `12 12 583 830`.
  Zero margins were reported as borderless, so jobs went out as
  `A4.Borderless` and the printer rejected the page size.
- Absolute filter paths rewritten from `/opt/konica225i` to
  `/usr/share/konica225i`.

Result: `media-key=iso_a4_210x297mm_auto_plain`, `cupsPageSizeName=A4`.

## Kept queues

- PAPPL native (`konica206-native.service`, port 8001): `konica206`,
  device `konica://KONICA MINOLTA/206?serial=A8A6041029423`, open C11 encoder.
- PAPPL legacy (`legacy-printer-app.service`, port 8000): `konica206uri` and
  `konica225i`, both on
  `cups:usb://KONICA%20MINOLTA/206?serial=A8A6041029423&interface=1`.
  `konica225i` uses the proprietary `245igdirf` filter from the vendor ZIP.
- Torchio: `konica206` (default), `konica225i`, `EPSON_L3260`.
  Epson uses `ipps://` because plain `ipp://` is rejected with HTTP 426.

Torchio printer registrations live in the user's persistent
`~/.local/state/torchio/state.db`, so they survive `bootc upgrade`.
`ensure-torchio-printers` re-adds any missing destination on a fresh login.

## Verification

```sh
systemctl --user is-active torchiod.service torchio-cups-proxy.service
/opt/torchio/bin/torchio doctor
/opt/torchio/bin/torchio printer ls
CUPS_SERVER=/run/user/$(id -u)/torchio-proxy/cups.sock lpstat -p -d
systemctl is-enabled cups.service cups.socket cups.path   # masked
legacy-printer-app printers
```

A test job should show `media-key=iso_a4_210x297mm_auto_plain` for Konica and
`scupsPageSizeName=A4` in the PAPPL journal.

## Undo / rollback

To go back to the stock Torchio daemon on this deployment only:

```sh
systemctl --user stop torchiod.service
sudo cp /tmp/opencode/torchiod-v0.1.0.orig /usr/local/bin/torchiod
systemctl --user start torchiod.service
```

To re-enable CUPS, remove `cups.service/socket/path` from the `masked` list in
`recipes/recipe.yml` and rebuild.

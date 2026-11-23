#!/usr/bin/env bash
# Install the desktop apps that are not packaged in Fedora/RPM Fusion as RPMs.
# Runs at image build time; every weekly rebuild resolves the newest upstream
# release, so these apps are updated by the same bootc upgrade path as the rest
# of the image (dnf install on the host would not survive an image update).
set -euxo pipefail

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# latest_github_rpm OWNER REPO FILENAME_SUFFIX FALLBACK_URL
# Prints the browser_download_url of the matching asset in the newest release.
# The GitHub API is rate-limited in CI, so fall back to a pinned known-good RPM.
latest_github_rpm() {
    local owner="$1" repo="$2" suffix="$3" fallback="$4" url=""
    url="$(curl --retry 3 -fsSL \
        "https://api.github.com/repos/${owner}/${repo}/releases/latest" \
        | python3 -c '
import json, sys
suffix = sys.argv[1]
data = json.load(sys.stdin)
for asset in data.get("assets", []):
    name = asset.get("name", "")
    if name.endswith(suffix) and "aarch64" not in name and "arm64" not in name:
        print(asset["browser_download_url"])
        break
else:
    tag = data.get("tag_name", "?")
    sys.exit("no RPM asset ending in " + suffix + " in " + str(tag))
' "$suffix")" || url=""
    if [ -z "$url" ]; then
        echo "WARNING: could not resolve latest ${owner}/${repo}; using pinned fallback" >&2
        url="$fallback"
    fi
    printf '%s\n' "$url"
}

NAPS2_FALLBACK=https://github.com/cyanfish/naps2/releases/download/v8.6.1/naps2-8.6.1-linux-x64.rpm
ZAPFAST_FALLBACK=https://github.com/crmne/zapfast/releases/download/v0.21.3/zapfast-0.21.3-1.x86_64.rpm

install_url() { # URL [sha256] -- download and install an RPM; log its version
    local url="$1"
    local file="$tmp/$(basename "$url")"
    curl --retry 3 --retry-delay 5 -fsSL -o "$file" "$url"
    if [ -n "${2:-}" ]; then
        echo "$2  $file" | sha256sum -c -
    fi
    rpm -qp --qf '%{NAME} %{VERSION}-%{RELEASE}\n' "$file" >&2 || true
    dnf -y --nogpgcheck install "$file"
}

# NAPS2 and ZapFast: resolve the newest release from GitHub.
install_url "$(latest_github_rpm cyanfish naps2 -linux-x64.rpm "$NAPS2_FALLBACK")"
install_url "$(latest_github_rpm crmne zapfast -1.x86_64.rpm "$ZAPFAST_FALLBACK")"

# XnView MP and ONLYOFFICE publish stable "latest RPM" URLs.
install_url https://download.xnview.com/XnView_MP-linux.x86_64.rpm
install_url https://download.onlyoffice.com/install/desktop/editors/linux/onlyoffice-desktopeditors.x86_64.rpm

# NAPS2 config lives in ~/.config/naps2 for the native RPM (same path the old
# Flatpak used via its xdg-config override); scan profiles are shipped in
# extras/flatpak/naps2/profiles.xml and installed on the target machine.
echo "Vendor app RPMs installed:"
rpm -q naps2 zapfast XnViewMP onlyoffice-desktopeditors 2>/dev/null || true

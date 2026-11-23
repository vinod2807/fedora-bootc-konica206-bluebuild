#!/usr/bin/env bash
# Back up the Flatpak Firefox profile and restore it into the native RPM
# Firefox profile directory. Run BEFORE uninstalling the Firefox Flatpak with
# --delete-data (extras/scripts/uninstall-replaced-flatpaks.sh calls this).
set -euo pipefail

APP_ID=org.mozilla.firefox
backup_root="${XDG_DATA_HOME:-$HOME/.local/share}/konica206/backups"
stamp="$(date +%Y%m%d-%H%M%S)"

dest="$HOME/.mozilla/firefox"

# Flatpak Firefox has used several profile locations over time: the private
# app home, its data/config subdirs, and (on this machine) the host XDG config
# dir. Check them all; never treat the native destination itself as a source.
src=""
for candidate in \
    "$HOME/.var/app/$APP_ID/.mozilla/firefox" \
    "$HOME/.var/app/$APP_ID/data/.mozilla/firefox" \
    "$HOME/.var/app/$APP_ID/config/mozilla/firefox" \
    "$HOME/.config/mozilla/firefox" \
    "$HOME/.mozilla/firefox"; do
    if [ "$candidate" = "$dest" ]; then
        continue
    fi
    if [ -d "$candidate" ]; then
        src="$candidate"
        break
    fi
done

if [ -z "$src" ]; then
    printf 'No Flatpak Firefox profile found; nothing to migrate.\n' >&2
    exit 0
fi

mkdir -p "$backup_root"
backup="$backup_root/firefox-flatpak-$stamp"
cp -a "$src" "$backup"
printf 'Flatpak Firefox profile backed up to: %s\n' "$backup"

if [ -e "$dest" ] && [ ! -d "$dest" ]; then
    printf 'Refusing to migrate: %s exists but is not a directory.\n' "$dest" >&2
    exit 1
fi
if [ -d "$dest" ] && [ -n "$(ls -A "$dest")" ]; then
    prior="$backup_root/firefox-native-before-migration-$stamp"
    cp -a "$dest" "$prior"
    printf 'Existing native profile backed up to: %s\n' "$prior"
fi

mkdir -p "$dest"
cp -a "$src"/. "$dest"/

# Absolute paths in profiles.ini can still point inside the Flatpak sandbox.
if [ -f "$dest/profiles.ini" ]; then
    sed -i \
        -e "s#$src#$dest#g" \
        -e "s#$HOME/.var/app/$APP_ID#$HOME#g" \
        "$dest/profiles.ini"
    printf 'Restored profiles:\n'
    grep -E '^(Name|Path)=' "$dest/profiles.ini" || true
fi

printf 'Done. Native Firefox profile: %s\n' "$dest"
printf 'Keep the backup at %s until you have verified bookmarks and logins.\n' "$backup"

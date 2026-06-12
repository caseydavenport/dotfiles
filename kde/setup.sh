#!/usr/bin/env bash
# Restore the KDE Plasma snapshot in kde/files/ onto this machine.
# Installs Plasma packages, backs up any existing config, then copies the
# snapshot into place. Idempotent. See KDE-SETUP.md for the full procedure.
#
# Do NOT run this from inside a Plasma session - kded5/plasmashell rewrite
# their config files on logout and will clobber the restore. Run from a TTY,
# over SSH, or before logging into Plasma for the first time.
set -euo pipefail

exec > >(tee /tmp/kde-setup.log) 2>&1

cd "$(dirname "$0")"

if [ ! -d files/config ]; then
    echo "ERROR: kde/files/ is missing - run export.sh on the source machine first." >&2
    exit 1
fi

if pgrep -u "$USER" -x plasmashell >/dev/null 2>&1; then
    echo "ERROR: a Plasma session is running for $USER." >&2
    echo "Log out and run this from a TTY (ctrl+alt+F3) or over SSH." >&2
    exit 1
fi

echo "==> Installing packages"
sudo apt-get update
xargs -a packages.txt sudo apt-get install -y

echo "==> Backing up existing config"
BACKUP="$HOME/kde-config-backup-$(date +%Y%m%d-%H%M%S)"
backed_up=0
for f in files/config/*; do
    name="$(basename "$f")"
    if [ -e "$HOME/.config/$name" ]; then
        mkdir -p "$BACKUP/.config"
        cp -a "$HOME/.config/$name" "$BACKUP/.config/"
        backed_up=1
    fi
done
for f in files/local/*; do
    name="$(basename "$f")"
    if [ -e "$HOME/.local/share/$name" ]; then
        mkdir -p "$BACKUP/.local/share"
        cp -a "$HOME/.local/share/$name" "$BACKUP/.local/share/"
        backed_up=1
    fi
done
if [ "$backed_up" = 1 ]; then
    echo "  existing config backed up to $BACKUP"
else
    echo "  nothing to back up"
fi

echo "==> Restoring ~/.config"
mkdir -p "$HOME/.config"
cp -a files/config/. "$HOME/.config/"

echo "==> Restoring ~/.local/share"
mkdir -p "$HOME/.local/share"
cp -a files/local/. "$HOME/.local/share/"

if [ -d files/home-files ]; then
    echo "==> Restoring wallpaper images (paths relative to ~)"
    cp -a files/home-files/. "$HOME/"
fi

echo
echo "Done. Full log at /tmp/kde-setup.log."
echo "Next: reboot (or 'sudo systemctl restart sddm'), pick 'Plasma (X11)' in SDDM, and log in."
echo "Then continue with the verification steps in KDE-SETUP.md."

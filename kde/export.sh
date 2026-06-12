#!/usr/bin/env bash
# Snapshot this machine's KDE Plasma config into kde/files/ for replication
# on another machine (see KDE-SETUP.md). Read-only against $HOME; only
# writes into the repo. Re-run any time the desktop config changes, then
# commit the diff.
set -euo pipefail

cd "$(dirname "$0")"
DEST="files"

# ~/.config items to snapshot. Relative to ~/.config.
CONFIG_ITEMS=(
    kdeglobals
    kwinrc
    kwinrulesrc
    kglobalshortcutsrc
    khotkeysrc
    plasma-org.kde.plasma.desktop-appletsrc
    plasmashellrc
    plasmarc
    plasmanotifyrc
    plasma_workspace.notifyrc
    plasma-localerc
    krunnerrc
    kscreenlockerrc
    kcminputrc
    kded5rc
    dolphinrc
    konsolerc
    konsolesshconfig
    spectaclerc
    powermanagementprofilesrc
    xdg-desktop-portal-kderc
    gtkrc
    gtkrc-2.0
    autostart
    kdedefaults
    gtk-3.0
    gtk-4.0
)

# ~/.local/share items to snapshot. Relative to ~/.local/share.
# icons/ and applications/ are handled separately below - they accumulate
# machine-specific junk (Chrome PWA shims, wine handlers, hicolor cache)
# that shouldn't land in the repo.
LOCAL_ITEMS=(
    plasma
    color-schemes
    aurorae
    konsole
    kscreen
    wallpapers
)

# Curated entries within icons/ and applications/.
ICON_ITEMS=(
    icons/Catppuccin-Mocha-Dark-Cursors
    icons/Catppuccin-Mocha-Mauve-Cursors
    icons/chrome-personal.png
    icons/chrome-personal.svg
    icons/chrome-work.png
    icons/chrome-work.svg
)
APPLICATION_ITEMS=(
    applications/chrome-personal.desktop
    applications/chrome-work.desktop
    applications/mimeapps.list
)

# Start fresh so deletions on the desktop propagate to the snapshot.
rm -rf "$DEST"
mkdir -p "$DEST/config" "$DEST/local"

copy_item() {
    local src="$1" dst="$2" name="$3"
    if [ -e "$src" ]; then
        cp -a "$src" "$dst/"
        echo "  copied $name"
    else
        echo "  skipped $name (not present)"
    fi
}

echo "Snapshotting ~/.config:"
for item in "${CONFIG_ITEMS[@]}"; do
    copy_item "$HOME/.config/$item" "$DEST/config" "$item"
done

echo "Snapshotting ~/.local/share:"
for item in "${LOCAL_ITEMS[@]}"; do
    copy_item "$HOME/.local/share/$item" "$DEST/local" "$item"
done
mkdir -p "$DEST/local/icons" "$DEST/local/applications"
for item in "${ICON_ITEMS[@]}"; do
    copy_item "$HOME/.local/share/$item" "$DEST/local/icons" "$item"
done
for item in "${APPLICATION_ITEMS[@]}"; do
    copy_item "$HOME/.local/share/$item" "$DEST/local/applications" "$item"
done

# Wallpapers referenced by the desktop containments may live outside
# ~/.local/share/wallpapers (e.g. ~/Pictures). Snapshot them under
# home-files/ preserving their path relative to $HOME - both machines use
# the same username, so the absolute Image= paths in appletsrc work
# unmodified once setup.sh restores these to the same spot.
APPLETSRC="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
if [ -f "$APPLETSRC" ]; then
    echo "Snapshotting wallpaper images:"
    grep -h '^Image=' "$APPLETSRC" | sed 's/^Image=//' | sed 's|^file://||' | sort -u | while read -r img; do
        img="${img/#\~/$HOME}"
        case "$img" in
            "$HOME"/.local/share/wallpapers/*) continue ;; # already snapshotted above
            /usr/*) echo "  skipped $img (system wallpaper, comes from packages)"; continue ;;
        esac
        if [ -f "$img" ]; then
            rel="${img#"$HOME"/}"
            mkdir -p "$DEST/home-files/$(dirname "$rel")"
            cp -a "$img" "$DEST/home-files/$rel"
            echo "  copied ~/$rel"
        else
            echo "  skipped $img (not found)"
        fi
    done
fi

echo
echo "Snapshot written to kde/$DEST. Review with 'git status', then commit."

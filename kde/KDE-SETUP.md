# KDE Plasma setup

Replicates the desktop's Plasma config on another machine. Written for a Claude agent driving the setup with Casey at the keyboard, but works fine for a human too.

The snapshot in `files/` is the source of truth. It was taken with `./export.sh` on the desktop (Ubuntu 24.04, Plasma 5.27). Target machine must match - same Ubuntu release, same Plasma version from the stock archive. Don't apply a Plasma 5 snapshot to Plasma 6.

## Preconditions

- Ubuntu 24.04 on the target, this repo cloned, sudo available.
- Not logged into a Plasma session (it won't exist yet on a fresh machine - that's the ideal time to run this). `setup.sh` enforces this.

## Steps

1. From a TTY or SSH session: `make kde` (or `cd kde && ./setup.sh`). Installs Plasma packages, backs up any existing KDE config to `~/kde-config-backup-<timestamp>/`, restores the snapshot. Full log lands in `/tmp/kde-setup.log`.
2. Reboot, pick "Plasma (X11)" in SDDM, log in.
3. Install the apps behind the pinned task manager launchers (interactive, do these with Casey):
   - wezterm: .deb from https://wezterm.org/install/linux.html (not in apt).
   - steam: `sudo apt install steam-installer`.
   - CurseForge: download from https://www.curseforge.com/download/app (it's a .deb). Runs under the WoW/Proton setup, see `~/SyncThing/wow-setup/` if that's relevant on this machine.
   - Chrome: install google-chrome-stable (Google's apt repo). The snapshot ships `chrome-personal.desktop` and `chrome-work.desktop`, which launch Chrome with separate `--user-data-dir` dirs under `~/.config/` (see their `Exec=` lines). The dirs get created on first launch; sign in to the matching Google account in each.
4. Autostart entries, ask Casey about each:
   - `indicator-sound-switcher`: not in the stock archive, install from the PPA: `sudo add-apt-repository ppa:yktooo/ppa && sudo apt install indicator-sound-switcher`. Mainly useful docked with multiple audio outputs.
   - `disable-dpms.desktop`: desktop-specific (keeps the monitors from sleeping). Probably unwanted on a laptop - ask before keeping it.

## Things to know

- **Panels and monitors**: the snapshot is from a dual-monitor desktop. The laptop docks to an identical monitor setup, so the second screen's panel and the kscreen output profiles should light up correctly when docked. Undocked, Plasma 5.27 keeps the second screen's containment dormant. Verify both states.
- **Virtual desktops**: 4, named Personal / Work / Terminal / Four.
- **Pinned launchers** will show as broken icons until step 3's apps are installed. Expected.
- **Theme**: Catppuccin-Mocha-Mauve global theme ships in the snapshot (`~/.local/share/plasma/look-and-feel/`), no separate install needed.
- If something looks off after login, don't hand-edit the snapshot files on the target - fix it in System Settings there, or fix it on the desktop and re-run `export.sh` + re-apply. Hand edits get lost on the next restore.

## Verification checklist

After login (and again after docking):

- [ ] Catppuccin Mocha theme active (dark purple-ish, matches the desktop)
- [ ] 4 virtual desktops with the right names (check the pager / `ctrl+F8`)
- [ ] Panel layout matches the desktop; system tray contents look right
- [ ] Pinned launchers present: System Settings, file manager, Chrome personal, browser, wezterm, Steam, CurseForge
- [ ] Global shortcuts work (spot-check a few from System Settings > Shortcuts)
- [ ] Konsole opens with the right profile/colors
- [ ] Docked: both monitors arranged correctly, second panel appears
- [ ] Undocked: single screen sane, no orphaned panel weirdness

-- WezTerm config. Treat as a thin, fast frame around tmux.
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ============ appearance ============
config.font = wezterm.font_with_fallback {
  'JetBrains Mono',
  'Fira Code',
  'DejaVu Sans Mono',
}
config.font_size = 11.0
config.color_scheme = 'Tokyo Night'
config.window_background_opacity = 0.97
config.text_background_opacity = 1.0

-- Hide tabs/title bar — tmux is the source of truth.
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.window_decorations = 'RESIZE'  -- thin borders, no title bar
config.window_padding = { left = 4, right = 4, top = 2, bottom = 2 }

-- ============ behaviour ============
config.scrollback_lines = 50000
config.enable_scroll_bar = false
config.audible_bell = 'Disabled'
config.visual_bell = {
  fade_in_duration_ms = 60,
  fade_out_duration_ms = 60,
  target = 'CursorColor',
}

-- Don't let WezTerm intercept things tmux/shell already handle.
config.disable_default_key_bindings = false
config.send_composed_key_when_left_alt_is_pressed = false
config.send_composed_key_when_right_alt_is_pressed = false

-- ============ hyperlinks ============
-- Click file paths, URLs, even `file:line:col` from compiler output.
config.hyperlink_rules = wezterm.default_hyperlink_rules()
table.insert(config.hyperlink_rules, {
  regex = [[(?:^|\s)([./~][^\s:]+):(\d+)(?::(\d+))?]],
  format = 'file://$1',
  highlight = 1,
})

-- ============ mouse ============
-- Auto-copy on select. Finishing a drag puts the selection on both the
-- clipboard and the X11 primary, so Ctrl+Shift+V and middle-click both work.
config.mouse_bindings = {
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection',
  },
  -- Ctrl+click still opens hyperlinks (override drops the default, so re-add it).
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL',
    action = wezterm.action.OpenLinkAtMouseCursor,
  },
}

-- ============ keybinds ============
-- Keep it minimal so tmux owns most chords.
config.keys = {
  -- Quick font size tweaks
  { key = '=', mods = 'CTRL', action = wezterm.action.IncreaseFontSize },
  { key = '-', mods = 'CTRL', action = wezterm.action.DecreaseFontSize },
  { key = '0', mods = 'CTRL', action = wezterm.action.ResetFontSize },
  -- Copy mode (useful for scrolling/searching even with tmux)
  { key = 'PageUp',   mods = 'SHIFT', action = wezterm.action.ScrollByPage(-1) },
  { key = 'PageDown', mods = 'SHIFT', action = wezterm.action.ScrollByPage(1) },
  -- Fullscreen toggle (WezTerm's default is Alt+Enter; add F11 to match other apps)
  { key = 'F11', action = wezterm.action.ToggleFullScreen },
}

-- ============ window class for KWin rules ============
-- So KWin rules can target WezTerm separately from Konsole/GNOME Terminal.
-- Match this in ~/.config/kwinrulesrc against wmclass=org.wezfurlong.wezterm
-- (or substring "wezterm").

return config

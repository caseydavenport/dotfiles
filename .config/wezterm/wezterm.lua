-- WezTerm config. Treat as a thin, fast frame around tmux.
local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- ============ appearance ============
config.font = wezterm.font_with_fallback {
  'JetBrainsMono Nerd Font Mono',
  'Noto Color Emoji',
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

-- ============ rendering ============
-- WebGpu (Vulkan/GL via wgpu) over the default OpenGL front end: lower-latency,
-- smoother scrolling, and it offloads to the GPU. Falls back to software if no
-- GPU is available.
config.front_end = 'WebGpu'

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

-- ============ quick select ============
-- Ctrl+Shift+Space labels on-screen matches; type the hint to copy, no mouse.
-- These are appended to WezTerm's built-ins (URLs, email) — the keyboard
-- counterpart to auto-copy-on-select below.
-- All groups are non-capturing (?:...): WezTerm's QuickSelect copies the first
-- capture group when a pattern has one, so a capturing group here would select
-- only part of the match (e.g. "alico-typha" instead of the whole pod name).
-- Order is most-specific first so the whole token wins any overlap.
config.quick_select_patterns = {
  -- `claude --resume <session-id>`: grab the whole runnable command.
  [[claude --resume \S+]],
  -- Deployment/ReplicaSet pods: the pod-template-hash segment is the tell, so
  -- this stays off plain hyphenated words the way a bare name-suffix wouldn't.
  [[\b[a-z0-9](?:[-a-z0-9]*[a-z0-9])?-[a-z0-9]{7,10}-[a-z0-9]{5}\b]],
  -- Calico DaemonSet pods have no pod-template-hash (just name + 5-char suffix),
  -- so match them by known prefix to keep false positives down.
  [[\b(?:calico-node-windows|calico-node|csi-node-driver|calico-cni-plugin)-[a-z0-9]{5}\b]],
  -- IPv4, with optional /CIDR and :port
  [[\b\d{1,3}(?:\.\d{1,3}){3}(?:/\d{1,2})?(?::\d{1,5})?]],
  -- git SHAs, short and full
  [[\b[0-9a-f]{7,40}\b]],
}

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
  -- Ctrl+Shift+click selects and copies a whole command's output as one zone.
  -- Needs OSC 133 marks, so this only works in bare WezTerm, not through tmux.
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'CTRL|SHIFT',
    action = wezterm.action.Multiple {
      wezterm.action.SelectTextAtMouseCursor 'SemanticZone',
      wezterm.action.CompleteSelection 'ClipboardAndPrimarySelection',
    },
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
  -- Jump to previous/next shell prompt (OSC 133). Bare WezTerm only; inside
  -- tmux use prefix + [ then { / } (see .tmux.conf).
  { key = 'UpArrow',   mods = 'CTRL|SHIFT', action = wezterm.action.ScrollToPrompt(-1) },
  { key = 'DownArrow', mods = 'CTRL|SHIFT', action = wezterm.action.ScrollToPrompt(1) },
  -- Fullscreen toggle (WezTerm's default is Alt+Enter; add F11 to match other apps)
  { key = 'F11', action = wezterm.action.ToggleFullScreen },
}

-- ============ notifications ============
-- Toast when a long command finishes in an unfocused window. The shell (see
-- .zshrc) sets WEZTERM_NOTIFY once a command passes the threshold; we only
-- toast when this window isn't focused, so it stays quiet while you're watching
-- the terminal. The user var reaches us through tmux via allow-passthrough.
wezterm.on('user-var-changed', function(window, pane, name, value)
  if name == 'WEZTERM_NOTIFY' and not window:is_focused() then
    window:toast_notification('WezTerm', value, nil, 5000)
  end
end)

-- ============ window class for KWin rules ============
-- So KWin rules can target WezTerm separately from Konsole/GNOME Terminal.
-- Match this in ~/.config/kwinrulesrc against wmclass=org.wezfurlong.wezterm
-- (or substring "wezterm").

return config

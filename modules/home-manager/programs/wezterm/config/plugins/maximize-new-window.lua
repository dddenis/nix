local wezterm = require("wezterm")

wezterm.GLOBALS.seen_windows = wezterm.GLOBALS.seen_windows or {}

wezterm.on("window-config-reloaded", function(window)
    local id = window:window_id()

    local is_new_window = not wezterm.GLOBALS.seen_windows[id]
    wezterm.GLOBALS.seen_windows[id] = true

    if is_new_window then
        window:maximize()
    end
end)

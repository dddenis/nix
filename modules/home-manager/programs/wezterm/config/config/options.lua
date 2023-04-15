local wezterm = require("wezterm")

local M = {}

local is_darwin = string.find(wezterm.target_triple, "darwin") ~= nil

function M.apply_to_config(config)
    config.term = "wezterm"
    config.color_scheme = "GruvboxDark"

    config.font = wezterm.font_with_fallback({
        "Iosevka Fixed",
        { family = "Symbols Nerd Font Mono", scale = 0.75 },
    })
    config.font_size = 13.5
    config.dpi = is_darwin and 192 or nil

    config.window_decorations = "RESIZE"
    config.window_close_confirmation = "NeverPrompt"
    config.window_padding = {
        left = "0",
        right = "0",
        top = "0",
        bottom = "0",
    }
    config.enable_tab_bar = false
    config.native_macos_fullscreen_mode = true

    config.check_for_updates = false
end

return M

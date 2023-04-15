local wezterm = require("wezterm")

wezterm.GLOBALS = wezterm.GLOBALS or {}

require("plugins.maximize-new-window")

local config = wezterm.config_builder()

config.term = "wezterm"
config.color_scheme = "GruvboxDark"

config.font = wezterm.font_with_fallback({
    "Iosevka Fixed",
    { family = "Symbols Nerd Font Mono", scale = 0.75 },
})
config.font_size = 13.5

config.window_decorations = "RESIZE"
config.window_padding = {
    left = "0",
    right = "0",
    top = "0",
    bottom = "0",
}
config.enable_tab_bar = false

config.check_for_updates = false

return config

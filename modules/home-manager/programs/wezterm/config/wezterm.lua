local wezterm = require("wezterm")

wezterm.GLOBALS = wezterm.GLOBALS or {}

local config = wezterm.config_builder()

require("config.options").apply_to_config(config)
require("config.keymaps").apply_to_config(config)

require("plugins.maximize-new-window")

return config

local wezterm = require("wezterm")
local shared = require("config/shared")

local M = {}

local function super_to_ctrl(key)
    return {
        key = key,
        mods = "SUPER",
        action = wezterm.action.SendKey({ key = key, mods = "CTRL" }),
    }
end

local function gen_alpha_mappings()
    local mappings = {}
    for char = string.byte("a"), string.byte("z") do
        local key = string.char(char)
        table.insert(mappings, super_to_ctrl(key))
    end
    return mappings
end

function M.apply_to_config(config)
    config.keys = {
        {
            key = "f",
            mods = "CTRL|SUPER",
            action = wezterm.action.ToggleFullScreen,
        },
        {
            key = "v",
            mods = "CTRL|SHIFT",
            action = wezterm.action.PasteFrom("Clipboard"),
        },
    }

    if shared.is_darwin then
        table.insert(config.keys, super_to_ctrl("Space"))
        table.insert(config.keys, {
            key = "v",
            mods = "SUPER|SHIFT",
            action = wezterm.action.PasteFrom("Clipboard"),
        })

        local alpha_mappings = gen_alpha_mappings()
        for _, mapping in ipairs(alpha_mappings) do
            table.insert(config.keys, mapping)
        end
    end
end

return M

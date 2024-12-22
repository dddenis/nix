local wezterm = require("wezterm")

local M = {}

M.is_darwin = wezterm.target_triple:find("darwin") ~= nil
M.is_linux = wezterm.target_triple:find("linux") ~= nil

return M

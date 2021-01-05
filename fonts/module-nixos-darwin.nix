{ config, pkgs, lib, ... }:

let
  fonts = lib.user.filterMapConfigs (userConfig:
    if userConfig.fonts.enable' then userConfig.fonts.fonts else null) config;

in lib.mkIf (lib.not lib.isEmpty fonts) {
  fonts = {
    enableFontDir = true;
    fonts = lib.pipe fonts [ lib.flatten lib.unique ];
  };
}


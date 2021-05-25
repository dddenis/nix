{ config, lib, pkgs, ... }:

let
  isEnabled =
    lib.user.anyConfig (userConfig: userConfig.programs.alacritty.enable')
    config;

in lib.mkIf isEnabled {
  environment.extraInit = ''
    tic -xe alacritty,alacritty-direct ${pkgs.alacritty.src}/extra/alacritty.info
  '';
}

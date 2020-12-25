{ config, pkgs, lib, ... }:

let
  isEnabled =
    pkgs.lib.user.anyConfig (userConfig: userConfig.programs.direnv.enable')
    config;

in {
  config = lib.mkIf isEnabled {
    nix.extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';
  };
}

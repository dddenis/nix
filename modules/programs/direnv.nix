{ config, lib, ... }:

let cfg = config.programs.direnv;

in {
  options.programs.direnv.enable' = lib.mkEnableOption "direnv";

  config = lib.mkIf cfg.enable' {
    nix.extraOptions = ''
      keep-outputs = true
      keep-derivations = true
    '';

    hm.programs.direnv = {
      enable = true;
      enableZshIntegration = true;
    };
  };
}

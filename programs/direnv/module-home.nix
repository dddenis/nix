{ config, lib, ... }:

let cfg = config.programs.direnv;

in {
  options.programs.direnv.enable' = lib.mkEnableOption "direnv";

  config = lib.mkIf cfg.enable' {
    programs.direnv = {
      enable = true;
      enableNixDirenvIntegration = true;
      enableZshIntegration = true;
    };
  };
}

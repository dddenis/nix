{ config, lib, ... }:

let cfg = config.programs.bat;

in {
  options.programs.bat.enable' = lib.mkEnableOption "bat";

  config = lib.mkIf cfg.enable' {
    programs.bat = {
      enable = true;

      config = { theme = "gruvbox-dark"; };
    };
  };
}


{ config, lib, ... }:

let cfg = config.ddd.programs.bat;

in
{
  options.ddd.programs.bat.enable = lib.mkEnableOption "bat";

  config = lib.mkIf cfg.enable {
    programs.bat = {
      enable = true;

      config = { theme = "gruvbox-dark"; };
    };
  };
}

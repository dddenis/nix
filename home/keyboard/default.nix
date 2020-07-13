{ config, lib, ... }:

let cfg = config.home.keyboard';

in {
  options.home.keyboard'.enable' = lib.mkEnableOption "keyboard";

  config = lib.mkIf cfg.enable' {
    home.keyboard = {
      layout = "us,ru";
      options = [ "ctrl:nocaps" "grp:alt_space_toggle" ];
    };
  };
}

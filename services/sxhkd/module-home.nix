{ config, lib, nixosConfig, pkgs, ... }:

let cfg = config.services.sxhkd;

in {
  options.services.sxhkd.enable' = lib.mkEnableOption "sxhkd";

  config = lib.mkIf cfg.enable' {
    services.sxhkd = {
      enable = true;

      extraPath = "${nixosConfig.security.wrapperDir}:${nixosConfig.system.path}/bin";

      keybindings = {
        "hyper + shift + Return" =
          "${pkgs.alacritty}/bin/alacritty -e ${config.programs.tmux.launch}";
      };
    };
  };
}
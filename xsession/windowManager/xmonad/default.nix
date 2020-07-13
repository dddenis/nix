{ config, lib, pkgs, ... }:

let
  cfg = config.xsession.windowManager.xmonad;

  tmux = "${pkgs.tmux}/bin/tmux";
  tmux-attach = pkgs.writeShellScript "tmux-attach" ''
    (${tmux} ls | grep -vq attached && ${tmux} a) || ${tmux}
  '';

  xmonadConfig = with config.theme;
    pkgs.substituteAll {
      src = ./xmonad.hs;

      terminal = "${pkgs.alacritty}/bin/alacritty -e ${tmux-attach}";
      normalBorderColor = primary.background;
      focusedBorderColor = primary.background;
      currentWorkspaceColor = bright.white;
      workspaceColor = bright.black;
    };

in {
  options.xsession.windowManager.xmonad.enable' = lib.mkEnableOption "xmonad";

  config = lib.mkIf cfg.enable' {
    xsession.windowManager.xmonad = {
      enable = true;
      enableContribAndExtras = true;
      config = xmonadConfig;
    };
  };
}

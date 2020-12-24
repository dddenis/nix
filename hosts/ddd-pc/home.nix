{ lib, pkgs, ... }:

{
  imports = [
    ../../fonts
    ../../home
    ../../programs
    ../../services
    ../../theme
    ../../xdg
    ../../xresources
    ../../xserver
  ];

  home = {
    packages = with pkgs; [
      discord
      filezilla
      inkscape
      jetbrains.rider
      krita
      niv
      nnn
      postman
      slack
      spotify
      tdesktop
      unityhub
    ];

    stateVersion = "20.09";
  };

  fonts.enable' = true;

  programs = {
    alacritty.enable' = true;
    bat.enable' = true;
    command-not-found.enable = true;
    direnv.enable' = true;
    emacs.enable' = true;
    fzf.enable' = true;
    git.enable' = true;
    google-chrome.enable' = true;
    home-manager.enable = true;
    ripgrep.enable' = true;
    tmux.enable' = true;
    vim.enable' = true;
    vscode.enable' = true;
    zsh.enable' = true;
  };

  services = {
    flameshot.enable = true;
    kmonad.enable = true;
    sxhkd.enable' = true;
  };

  systemd.user.startServices = "sd-switch";

  xdg.enable = true;
  xresources.enable' = true;

  xserver.desktopManager.plasma5.enable' = true;
}

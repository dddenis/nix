{ lib, pkgs, ... }:

{
  imports = [
    ../fonts
    ../home/keyboard
    ../programs
    ../services
    ../theme
    ../xresources
    ../xsession/windowManager/xmonad
  ];

  home = {
    keyboard'.enable' = true;

    packages = with pkgs; [
      cachix
      discord
      dmenu
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
  };

  fonts.enable' = true;

  programs = {
    alacritty.enable' = true;
    bat.enable' = true;
    command-not-found.enable = true;
    direnv.enable' = true;
    emacs.enable' = true;
    feh.enable = true;
    fzf.enable' = true;
    git.enable' = true;
    google-chrome.enable' = true;
    home-manager.enable = true;
    mpv.enable = true;
    ripgrep.enable' = true;
    tmux.enable' = true;
    vim.enable' = true;
    vscode.enable' = true;
    zsh.enable' = true;
  };

  services = {
    flameshot.enable = true;
    lorri.enable' = true;
    polybar.enable' = true;
    xcape.enable' = true;
  };

  xdg.enable = true;
  xresources.enable' = true;

  xsession = {
    enable = true;
    windowManager.xmonad.enable' = true;
  };
}

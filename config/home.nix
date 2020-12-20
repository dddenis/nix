{ lib, pkgs, ... }:

{
  imports = [
    ../fonts
    ../home
    ../programs
    ../services
    ../theme
    ../xdg
    ../xresources
    ../xserver
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
    xcape.enable' = true;
  };

  xdg.enable = true;
  xresources.enable' = true;

  xserver.desktopManager.plasma5.enable' = true;
}

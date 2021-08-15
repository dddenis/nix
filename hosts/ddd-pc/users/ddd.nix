{ config, lib, pkgs, ... }:

{
  fonts.enable' = true;

  home = {
    enable' = true;

    bookmarks = builtins.mapAttrs (_: path: config.home.homeDirectory + path) {
      vn = "/dev/dddenis/vn";
    };

    packages = with pkgs; [
      discord
      fd
      filezilla
      firefox-wayland
      git
      godot
      godot-mono
      google-chrome
      htop
      inkscape
      jetbrains.rider
      krita
      niv
      postman
      slack
      tdesktop
      xclip
    ];
  };

  programs = {
    alacritty.enable' = true;
    atool.enable' = true;
    bat.enable' = true;
    direnv.enable' = true;
    emacs.enable' = true;
    fzf.enable' = true;
    git.enable' = true;
    lazygit.enable' = true;
    less.enable' = true;
    nix-index.enable' = true;
    nnn.enable' = true;
    ripgrep.enable' = true;
    spotify.enable' = true;
    tmux.enable' = true;
    unityhub.enable' = true;
    vim.enable' = true;
    vscode.enable' = true;
    zsh.enable' = true;
  };

  services = {
    flameshot.enable = true;
    kmonad.enable' = true;
    sxhkd.enable' = true;
  };

  systemd.user.startServices = "sd-switch";

  xresources.enable' = true;
}

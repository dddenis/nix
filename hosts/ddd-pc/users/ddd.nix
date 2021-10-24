{ config, lib, pkgs, ... }:

{
  fonts.enable' = true;

  home = {
    enable' = true;

    bookmarks = builtins.mapAttrs (_: path: config.home.homeDirectory + path) {
      vn = "/dev/dddenis/vn";
    };

    packages = with pkgs; [
      chromium
      discord
      docker-compose
      fd
      filezilla
      firefox-wayland
      git
      gnumake
      htop
      inkscape
      insomnia
      krita
      lazydocker
      niv
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
    fzf.enable' = true;
    git.enable' = true;
    lazygit.enable' = true;
    less.enable' = true;
    mpv.enable = true;
    nix-index.enable' = true;
    nnn.enable' = true;
    ripgrep.enable' = true;
    spotify.enable' = true;
    tmux.enable' = true;
    vim.enable' = true;
    vscode.enable' = true;
    zsh.enable' = true;
  };

  services = {
    kmonad.enable' = true;
  };

  systemd.user.startServices = "sd-switch";

  xdg.mimeApps.defaultApplications = {
    "application/xhtml+xml" = "firefox.desktop";
    "text/html" = "firefox.desktop";
    "text/xml" = "firefox.desktop";
    "x-scheme-handler/ftp" = "firefox.desktop";
    "x-scheme-handler/http" = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
  };

  xresources.enable' = true;
}

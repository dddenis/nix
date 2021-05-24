{ config, lib, pkgs, ... }:

{
  fonts.enable' = true;

  home = {
    enable' = true;
    bookmarks = builtins.mapAttrs (_: path: config.home.homeDirectory + path) {
      portal = "/dev/mcmakler/portal";
      public-gql = "/dev/mcmakler/public-gql";
    };
    packages = with pkgs; [ coreutils fd htop niv ];
  };

  programs = {
    alacritty.enable' = true;
    atool.enable' = true;
    bat.enable' = true;
    direnv.enable' = true;
    emacs.enable' = true;
    fzf.enable' = true;
    git = {
      enable' = true;
      userEmail = "denis.goncharenko@mcmakler.de";
    };
    lazygit.enable' = true;
    less.enable' = true;
    nix-index.enable' = true;
    nnn.enable' = true;
    ripgrep.enable' = true;
    tmux.enable' = true;
    vim.enable' = true;
    vscode.enable' = true;
    zsh = {
      enable' = true;
      shellAliases = { ls = "ls --color"; };
    };
  };

  services.karabiner.enable' = true;
}

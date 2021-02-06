{ config, lib, pkgs, ... }:

let cfg = config.programs.nix-index;

in {
  options.programs.nix-index.enable' = lib.mkEnableOption "nix-index";

  config = lib.mkIf cfg.enable' {
    home.packages = [ pkgs.nix-index ];

    programs.zsh.initExtra = ''
      source ${pkgs.nix-index}/etc/profile.d/command-not-found.sh
    '';
  };
}


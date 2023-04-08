{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.homebrew;

in
{
  options.ddd.programs.homebrew.enable = lib.mkEnableOption "homebrew";

  config = lib.mkIf cfg.enable {
    programs.zsh.profileExtra = ''
      if [ -f /opt/homebrew/bin/brew ]; then
        fpath+=/opt/homebrew/share/zsh/site-functions
        eval "$(/opt/homebrew/bin/brew shellenv)"
      fi
    '';
  };
}

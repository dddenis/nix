{ inputs, config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.vim;

in
{
  options.ddd.programs.vim = {
    enable = lib.mkEnableOption "vim";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ config.programs.ddd.neovim.finalPackage ];

    programs.ddd.neovim.viAlias = true;
    programs.ddd.neovim.vimAlias = true;
  };
}

{ inputs, config, lib, pkgs, ... }:

let
  cfg = config.programs.vim;

in
{
  options.programs.vim = {
    enable' = lib.mkEnableOption "vim";
  };

  config = lib.mkIf cfg.enable' {
    hm.home.packages = [ config.programs.ddd.neovim.finalPackage ];

    environment.variables.EDITOR = "nvim";

    programs.ddd.neovim.viAlias = true;
    programs.ddd.neovim.vimAlias = true;
  };
}

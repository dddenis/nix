{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.yaml;

in {
  options.programs.vim.yaml.enable' = lib.mkEnableOption "vim.yaml";

  config = lib.mkIf cfg.enable' {
    hm.programs.neovim.plugins = with pkgs.vimPlugins; [ coc-yaml ];

    programs.vim.coc-nvim.filetypeMap = { "yaml.docker-compose" = "yaml"; };
  };
}

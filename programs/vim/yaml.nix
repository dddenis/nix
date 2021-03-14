{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.yaml;

in {
  options.programs.vim.yaml.enable' = lib.mkEnableOption "vim.yaml";

  config = lib.mkIf cfg.enable' {
    programs = {
      neovim.plugins = with pkgs.vimPlugins; [ coc-yaml ];

      vim.coc-nvim.filetypeMap = { "yaml.docker-compose" = "yaml"; };
    };
  };
}

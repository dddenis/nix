{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.coc-diagnostic;

in {
  options.programs.vim.coc-diagnostic = {
    enable' = lib.mkEnableOption "vim.coc-diagnostic";

    filetypes = lib.mkOption {
      type = with lib.types; attrsOf (either string (nonEmptyListOf string));
      default = { };
    };

    linters = lib.mkOption {
      type = with lib.types; attrsOf attrs;
      default = { };
    };

    formatFiletypes = lib.mkOption {
      type = with lib.types; attrsOf (either string (nonEmptyListOf string));
      default = { };
    };

    formatters = lib.mkOption {
      type = with lib.types; attrsOf attrs;
      default = { };
    };
  };

  config = lib.mkIf cfg.enable' {
    hm.programs.neovim.plugins = with pkgs.vimPlugins; [ coc-diagnostic ];

    programs.vim.coc-nvim.coc-settings = {
      "diagnostic-languageserver.mergeConfig" = true;
      "diagnostic-languageserver.filetypes" = cfg.filetypes;
      "diagnostic-languageserver.linters" = cfg.linters;
      "diagnostic-languageserver.formatFiletypes" = cfg.formatFiletypes;
      "diagnostic-languageserver.formatters" = cfg.formatters;
    };
  };
}

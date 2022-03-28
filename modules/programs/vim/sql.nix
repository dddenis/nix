{ config, lib, pkgs, ... }:

let
  inherit (config.programs.vim) leader;

  cfg = config.programs.vim.sql;

in {
  options.programs.vim.sql.enable' = lib.mkEnableOption "vim.sql";

  config = lib.mkIf cfg.enable' {
    hm.programs.neovim.extraConfig = ''
      autocmd FileType sql xnoremap <buffer> <CR> :w !psql -1 -f -<CR>
    '';

    programs.vim.coc-nvim = {
      globalExtensions = [ "coc-sql" ];

      coc-settings = { "sql.formatOptions" = { "linesBetweenQueries" = 2; }; };
    };
  };
}


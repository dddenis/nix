{ config, lib, pkgs, ... }:

let
  inherit (config.programs.vim) leader;

  cfg = config.programs.vim.nix;

in {
  options.programs.vim.nix.enable' = lib.mkEnableOption "vim.nix";

  config = lib.mkIf cfg.enable' {
    programs.neovim = {
      extraConfig = ''
        autocmd FileType nix setlocal formatprg=${pkgs.nixfmt}/bin/nixfmt
        autocmd FileType nix nmap <buffer><silent> <${leader}>cf :%!${pkgs.nixfmt}/bin/nixfmt<CR>
      '';

      plugins = with pkgs.vimPlugins; [ vim-nix ];
    };
  };
}

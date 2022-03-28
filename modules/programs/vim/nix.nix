{ config, lib, pkgs, ... }:

let
  inherit (config.programs.vim) leader;

  cfg = config.programs.vim.nix;

in {
  options.programs.vim.nix.enable' = lib.mkEnableOption "vim.nix";

  config = lib.mkIf cfg.enable' {
    hm.programs.neovim = {
      extraConfig = ''
        autocmd FileType nix setlocal iskeyword-=-
      '';

      plugins = with pkgs.vimPlugins; [ vim-nix ];
    };

    programs.vim.coc-diagnostic = {
      formatFiletypes = { nix = "nixfmt"; };

      formatters = { nixfmt.command = "${pkgs.nixfmt}/bin/nixfmt"; };
    };
  };
}

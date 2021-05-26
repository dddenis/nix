{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.coc-sh;

in {
  options.programs.vim.coc-sh.enable' = lib.mkEnableOption "vim.coc-sh";

  config = lib.mkIf cfg.enable' {
    programs.vim.coc-nvim.globalExtensions = [ "coc-sh" ];

    programs.vim.coc-diagnostic = {
      filetypes = { sh = "shellcheck"; };

      linters = { shellcheck.command = "${pkgs.shellcheck}/bin/shellcheck"; };

      formatFiletypes = { sh = "shfmt"; };

      formatters = {
        shfmt = {
          command = "${pkgs.shfmt}/bin/shfmt";
          args = [ "-i" "2" ];
        };
      };
    };
  };
}


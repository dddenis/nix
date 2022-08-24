{ config, lib, pkgs, ... }:

let cfg = config.programs.vim.terraform;

in {
  options.programs.vim.terraform.enable' = lib.mkEnableOption "vim.terraform";

  config = lib.mkIf (config.programs.vim.coc-nvim.enable' && cfg.enable') {
    programs.vim.coc-nvim.coc-settings = {
      languageserver = {
        terraform = {
          command = "${pkgs.terraform-ls}/bin/terraform-ls";
          args = [ "serve" ];
          filetypes = [ "terraform" "tf" ];
          initializationOptions = { };
          settings = { };
        };
      };
    };
  };
}

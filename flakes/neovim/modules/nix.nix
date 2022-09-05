{ pkgs, ... }:

{
  config.programs.ddd.neovim.lsp.client.rnix = { };

  config.programs.ddd.neovim.packages = with pkgs; [
    ddd.rnix-lsp
  ];
}

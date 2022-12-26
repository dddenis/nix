{ neovimPkgs, ... }:

{
  config.programs.ddd.neovim.lsp.client.rnix = { };

  config.programs.ddd.neovim.packages = with neovimPkgs; [
    rnix-lsp
  ];
}

{ neovimPkgs, ... }:

{
  config.programs.ddd.neovim.lsp.client.pyright = { };

  config.programs.ddd.neovim.packages = with neovimPkgs; [
    nodePackages.pyright
  ];
}

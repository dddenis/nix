{ neovimPkgs, ... }:

{
  config.programs.ddd.neovim.lsp.client.jsonls = { };

  config.programs.ddd.neovim.packages = with neovimPkgs; [
    nodePackages.vscode-langservers-extracted
  ];
}

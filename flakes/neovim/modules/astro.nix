{ neovimPkgs, ... }:

{
  config.programs.ddd.neovim.lsp.client.astro = { };

  config.programs.ddd.neovim.packages = with neovimPkgs; [
    nodePackages."@astrojs/language-server"
  ];
}

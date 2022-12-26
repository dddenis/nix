{ neovimPkgs, ... }:

{
  config.programs.ddd.neovim.lsp.client.terraformls = { };

  config.programs.ddd.neovim.packages = with neovimPkgs; [
    terraform-ls
  ];
}

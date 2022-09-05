{ pkgs, ... }:

{
  config.programs.ddd.neovim.lsp.client.bashls = { };

  config.programs.ddd.neovim.packages = with pkgs; [
    nodePackages.bash-language-server
    shellcheck
  ];
}

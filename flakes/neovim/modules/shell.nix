{ pkgs, ... }:

{
  config.programs.ddd.neovim.lsp.client.bashls = { };

  config.programs.ddd.neovim.lsp.null-ls.sources = [
    "require'null-ls'.builtins.formatting.shellharden"
    "require'null-ls'.builtins.formatting.shfmt"
  ];

  config.programs.ddd.neovim.packages = with pkgs; [
    nodePackages.bash-language-server
    shellcheck
    shellharden
    shfmt
  ];
}

{ pkgs, ... }:

{
  config.programs.ddd.neovim.lsp.client.rust_analyzer = {
    settings.rust-analyzer = {
      completion.callable.snippets = "none";
    };
  };

  config.programs.ddd.neovim.packages = with pkgs; [
    rust-analyzer
  ];
}

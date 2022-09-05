{ config, lib, pkgs, ... }:

{
  imports = [
    ./completion.nix
    ./git.nix
    ./haskell.nix
    ./lsp.nix
    ./neovim.nix
    ./nix.nix
    ./rust.nix
    ./shell.nix
    ./sql.nix
    ./status-line.nix
    ./telescope.nix
    ./terraform.nix
    ./theme.nix
    ./treesitter.nix
    ./typescript.nix
  ];
}

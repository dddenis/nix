{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.vim;

  neovim = pkgs.unstable.wrapNeovimUnstable pkgs.unstable.neovim-unwrapped {
    vimAlias = true;
    wrapRc = false;
    wrapperArgs = lib.concatStringsSep " " [
      ''--set CC "${pkgs.gcc}/bin/gcc"''
      ''--suffix PATH : "${lib.makeBinPath packages}"''
    ];
  };

  packages = with pkgs.unstable; [
    gopls
    lua-language-server
    nil
    nixpkgs-fmt
    nodePackages."@astrojs/language-server"
    nodePackages.bash-language-server
    nodePackages.prettier
    nodePackages.sql-formatter
    nodePackages.svelte-language-server
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    pyright
    rust-analyzer
    shellcheck
    shellharden
    shfmt
    stylua
    terraform-ls
    tree-sitter
  ];

in
{
  options.ddd.programs.vim.enable = lib.mkEnableOption "vim";

  config = lib.mkIf cfg.enable {
    home.packages = [ neovim ];
    home.sessionVariables = {
      EDITOR = "nvim";
    };
    xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.configPath}/modules/home-manager/programs/neovim/nvim";
  };
}

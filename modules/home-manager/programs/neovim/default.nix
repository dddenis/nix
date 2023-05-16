{ config, lib, pkgs, ... }:

let
  cfg = config.ddd.programs.vim;

  neovim = pkgs.unstable.wrapNeovimUnstable pkgs.unstable.neovim-unwrapped {
    vimAlias = true;
    wrapRc = false;
    wrapperArgs = ''
      --set-default CC ${pkgs.stdenv.cc}/bin/cc \
      --suffix PATH : "${lib.makeBinPath packages}"
    '';
    packpathDirs.myNeovimPackages = {
      start = [ ];
      opt = [ ];
    };
  };

  packages = with pkgs.unstable; [
    gopls
    lua-language-server
    nodePackages."@astrojs/language-server"
    nodePackages.bash-language-server
    nodePackages.prettier
    nodePackages.pyright
    nodePackages.sql-formatter
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    rnix-lsp
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

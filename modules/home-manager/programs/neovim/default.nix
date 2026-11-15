{ config, lib, pkgs, ... }:

let cfg = config.ddd.programs.vim;

in
{
  options.ddd.programs.vim.enable = lib.mkEnableOption "vim";

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      package = pkgs.unstable.neovim-unwrapped;
      defaultEditor = true;
      vimAlias = true;
      withPython3 = false;
      withRuby = false;
      # ~/.config/nvim is a symlink to this repo, so nothing can be generated into it
      sideloadInitLua = true;
      extraWrapperArgs = [ "--set" "CC" "${pkgs.gcc}/bin/gcc" ];
      extraPackages = with pkgs.unstable; [
        clojure-lsp
        gopls
        lua-language-server
        nil
        nixpkgs-fmt
        astro-language-server
        bash-language-server
        prettier
        sql-formatter
        svelte-language-server
        typescript-language-server
        vscode-langservers-extracted
        nodejs
        pyright
        rust-analyzer
        shellcheck
        shellharden
        shfmt
        stylua
        terraform-ls
        tree-sitter
      ];
    };

    xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.configPath}/modules/home-manager/programs/neovim/nvim";
  };
}

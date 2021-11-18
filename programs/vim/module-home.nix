{ config, lib, pkgs, ... }:

let
  cfg = config.programs.vim;
  inherit (cfg) leader;

  desktopItem = pkgs.makeDesktopItem {
    name = "vim";
    desktopName = "vim";
    exec =
      "${pkgs.alacritty}/bin/alacritty -v -e ${config.programs.neovim.finalPackage}/bin/nvim %F";
  };

in {
  imports = [
    ./asterisk.nix
    ./bufkill.nix
    ./coc-nvim.nix
    ./floaterm.nix
    ./go.nix
    ./hardtime.nix
    ./haskell.nix
    ./lightline.nix
    ./nix.nix
    ./rust.nix
    ./sql.nix
    ./tmux.nix
    ./yaml.nix
  ];

  options.programs.vim = {
    enable' = lib.mkEnableOption "vim";

    leader = lib.mkOption {
      type = lib.types.str;
      default = "\\";
    };
  };

  config = lib.mkIf cfg.enable' {
    home = {
      sessionVariables.EDITOR = "vim";
      packages = with pkgs; [ desktopItem watchman ];
    };

    programs.vim = {
      leader = "Space";

      asterisk.enable' = true;
      bufkill.enable' = true;
      coc-nvim.enable' = true;
      floaterm.enable' = true;
      go.enable' = true;
      hardtime.enable' = true;
      haskell.enable' = true;
      lightline.enable' = true;
      nix.enable' = true;
      sql.enable' = true;
      rust.enable' = true;
      tmux.enable' = true;
      yaml.enable' = true;
    };

    programs.neovim = {
      enable = true;

      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;

      withNodeJs = true;

      extraConfig = lib.mkBefore ''
        set termguicolors
        let g:gruvbox_italic=1
        colorscheme gruvbox

        set nobackup
        set nowritebackup

        set scrolloff=5
        set sidescrolloff=5

        set clipboard=unnamedplus

        set number
        set relativenumber

        set colorcolumn=100

        set list
        set listchars=tab:▸-,trail:·,extends:›,precedes:‹,nbsp:␣

        set expandtab
        set softtabstop=2
        set shiftwidth=2

        set wildcharm=<C-z>

        cnoreabbrev h vert bo h

        set ignorecase
        set smartcase
        set inccommand=nosplit
        nnoremap <silent> <Esc> :<C-u>call coc#float#close_all() \| :nohlsearch<CR><Esc>

        cnoremap %% <C-r>=fnameescape(expand('%:h')).'/'<CR>

        set hidden
        nnoremap <silent> <${leader}>` :b#<CR>
        nnoremap <${leader}>fs :w<CR>

        set completeopt=menu,preview,noinsert
        set wildmode=longest:full,full
        cnoremap <expr> <C-j> pumvisible() ? "\<C-n>" : "\<Down>"
        cnoremap <expr> <C-k> pumvisible() ? "\<C-p>" : "\<Up>"
        cnoremap <expr> <C-l> pumvisible() ? " \<BS>" : "\<C-l>"
        inoremap <expr> <C-j> pumvisible() ? "\<Down>" : "\<C-n>"
        inoremap <expr> <C-k> pumvisible() ? "\<Up>" : "\<C-p>"

        inoremap <expr> <C-l> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<C-l>"
        inoremap <expr> <Tab> complete_info()["selected"] != "-1" ? "\<C-y>" : "\<Tab>"
      '';

      plugins = with pkgs.vimPlugins; [
        gruvbox-community
        quickfix-reflector-vim
        vim-abolish
        vim-commentary
        vim-polyglot
        vim-surround
      ];
    };
  };
}

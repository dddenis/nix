{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    neovim.url = "github:neovim/neovim?dir=contrib";
    neovim.inputs.flake-utils.follows = "flake-utils";

    vim-plugin-plenary.url = "github:nvim-lua/plenary.nvim";
    vim-plugin-plenary.flake = false;

    vim-plugin-gruvbox-material.url = "github:sainnhe/gruvbox-material";
    vim-plugin-gruvbox-material.flake = false;

    vim-plugin-lualine.url = "github:nvim-lualine/lualine.nvim";
    vim-plugin-lualine.flake = false;

    vim-plugin-treesitter.url = "github:nvim-treesitter/nvim-treesitter";
    vim-plugin-treesitter.flake = false;

    vim-plugin-telescope.url = "github:nvim-telescope/telescope.nvim";
    vim-plugin-telescope.flake = false;

    vim-plugin-telescope-fzf-native.url =
      "github:nvim-telescope/telescope-fzf-native.nvim";
    vim-plugin-telescope-fzf-native.flake = false;

    vim-plugin-telescope-live-grep-args.url =
      "github:nvim-telescope/telescope-live-grep-args.nvim";
    vim-plugin-telescope-live-grep-args.flake = false;

    vim-plugin-tmux-navigator.url = "github:christoomey/vim-tmux-navigator";
    vim-plugin-tmux-navigator.flake = false;

    vim-plugin-floaterm.url = "github:voldikss/vim-floaterm";
    vim-plugin-floaterm.flake = false;

    vim-plugin-fugitive.url = "github:tpope/vim-fugitive";
    vim-plugin-fugitive.flake = false;

    vim-plugin-gitsigns.url = "github:lewis6991/gitsigns.nvim";
    vim-plugin-gitsigns.flake = false;

    vim-plugin-mergetool.url = "github:samoshkin/vim-mergetool";
    vim-plugin-mergetool.flake = false;

    vim-plugin-autopairs.url = "github:windwp/nvim-autopairs";
    vim-plugin-autopairs.flake = false;

    vim-plugin-lspconfig.url = "github:neovim/nvim-lspconfig";
    vim-plugin-lspconfig.flake = false;

    vim-plugin-null-ls.url = "github:jose-elias-alvarez/null-ls.nvim";
    vim-plugin-null-ls.flake = false;

    vim-plugin-lspkind.url = "github:onsails/lspkind.nvim";
    vim-plugin-lspkind.flake = false;

    vim-plugin-lsp-signature.url = "github:ray-x/lsp_signature.nvim";
    vim-plugin-lsp-signature.flake = false;

    vim-plugin-luasnip.url = "github:L3MON4D3/LuaSnip";
    vim-plugin-luasnip.flake = false;

    vim-plugin-cmp.url = "github:hrsh7th/nvim-cmp";
    vim-plugin-cmp.flake = false;

    vim-plugin-cmp-luasnip.url = "github:saadparwaiz1/cmp_luasnip";
    vim-plugin-cmp-luasnip.flake = false;

    vim-plugin-cmp-nvim-lsp.url = "github:hrsh7th/cmp-nvim-lsp";
    vim-plugin-cmp-nvim-lsp.flake = false;

    vim-plugin-cmp-buffer.url = "github:hrsh7th/cmp-buffer";
    vim-plugin-cmp-buffer.flake = false;

    vim-plugin-cmp-path.url = "github:hrsh7th/cmp-path";
    vim-plugin-cmp-path.flake = false;

    vim-plugin-comment.url = "github:numToStr/Comment.nvim";
    vim-plugin-comment.flake = false;

    vim-plugin-sleuth.url = "github:tpope/vim-sleuth";
    vim-plugin-sleuth.flake = false;

    vim-plugin-abolish.url = "github:tpope/vim-abolish";
    vim-plugin-abolish.flake = false;

    vim-plugin-repeat.url = "github:tpope/vim-repeat";
    vim-plugin-repeat.flake = false;

    vim-plugin-surround.url = "github:tpope/vim-surround";
    vim-plugin-surround.flake = false;

    vim-plugin-unimpaired.url = "github:tpope/vim-unimpaired";
    vim-plugin-unimpaired.flake = false;

    vim-plugin-bufdelete.url = "github:famiu/bufdelete.nvim";
    vim-plugin-bufdelete.flake = false;

    vim-plugin-asterisk.url = "github:haya14busa/vim-asterisk";
    vim-plugin-asterisk.flake = false;

    vim-plugin-dressing.url = "github:stevearc/dressing.nvim";
    vim-plugin-dressing.flake = false;
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, neovim, ... }:
    (rec {
      overlays.default = overlays.neovim;
      overlays.neovim = (
        final: prev:
          let
            pkgs = self.packages."${prev.system}";
          in
          {
            neovim-unwrapped = pkgs.neovim-unwrapped;

            vimPlugins = (prev.vimPlugins or { }) // (
              prev.lib.attrsets.mapAttrs'
                (name: value: {
                  inherit value;
                  name = prev.lib.strings.removePrefix "vim-plugin-" name;
                })
                (final.lib.ddd.filterPlugins pkgs)
            );
          }
          // (import ./lib.nix final prev)
      );

      nixosModules.default = nixosModules.neovim;
      nixosModules.neovim = { config, ... }: {
        imports = [ ./modules ];

        config._module.args.neovimPkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [ self.overlays.default ];
        };
      };
    }
    // flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlays.default ];
        };
        inherit (pkgs) lib;

        eval = lib.evalModules {
          modules = [ ./modules ];
          specialArgs = {
            inherit pkgs lib;
          };
        };

      in
      rec {
        packages = (
          {
            default = packages.neovim;
            neovim-unwrapped = neovim.packages."${system}".neovim;
            neovim = eval.config.programs.ddd.neovim.finalPackage;
            vimrc = pkgs.writeText ".vimrc" eval.config.programs.ddd.neovim.customRC;
          }
          // lib.mapAttrs lib.ddd.buildPlugin (lib.ddd.filterPlugins inputs)
        );

        apps.default = apps.neovim;

        apps.neovim = flake-utils.lib.mkApp {
          drv = packages.neovim;
          exePath = "/bin/nvim";
        };
      })
    );
}

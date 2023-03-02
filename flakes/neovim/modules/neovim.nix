{ config, lib, neovimPkgs, ... }:

let
  cfg = config.programs.ddd.neovim;

in
{
  options.programs.ddd.neovim = {
    viAlias = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    vimAlias = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = neovimPkgs.neovim-unwrapped;
    };

    finalPackage = lib.mkOption {
      type = lib.types.package;
      visible = false;
      readOnly = true;
    };

    customRC = lib.mkOption {
      type = lib.types.lines;
      default = "";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
    };

    plugins = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
    };
  };

  config.programs.ddd.neovim = {
    finalPackage = neovimPkgs.wrapNeovim cfg.package {
      inherit (cfg) viAlias vimAlias;

      configure.customRC = ''
        lua << EOF
          function map_with(def)
            return function(mode, l, r, opts)
              local result = {}
              for k, v in pairs(def or {}) do 
                result[k] = v
              end
              for k, v in pairs(opts or {}) do 
                result[k] = v
              end
              vim.keymap.set(mode, l, r, result)
            end
          end

          local map = map_with({ silent = true })

          vim.g.mapleader = ' '
          vim.opt.clipboard = 'unnamedplus'

          vim.opt.backup = false
          vim.opt.writebackup = false

          vim.opt.scrolloff = 5
          vim.opt.sidescrolloff = 5

          vim.opt.signcolumn = 'yes'
          vim.opt.number = true
          vim.opt.relativenumber = true

          vim.opt.list = true
          vim.opt.listchars = {
            tab = '▸-',
            trail = '·',
            extends = '›',
            precedes = '‹',
            nbsp = '␣',
          }

          vim.opt.expandtab = true
          vim.opt.tabstop = 4
          vim.opt.softtabstop = 2
          vim.opt.shiftwidth = 2

          vim.opt.ignorecase = true
          vim.opt.smartcase = true
          map('n', '<esc>', ':nohlsearch<cr>')

          vim.g.tmux_navigator_disable_when_zoomed = 1

          map('n', '<leader>`', ':b#<cr>')
          map('n', '<leader>fs', ':w<cr>')
          map('n', '<leader>dw', ':windo diffthis<cr>')
          map('n', '<leader>do', ':diffoff!<cr>')

          map('n', '<leader>bd', ':Bdelete<cr>')
          map('n', '<leader>bD', ':Bdelete!<cr>')

          vim.g['asterisk#keeppos'] = 1
          map(''', '*', '<plug>(asterisk-z*)')
          map(''', '#', '<plug>(asterisk-z#)')
          map(''', 'g*', '<plug>(asterisk-gz*)')
          map(''', 'g*', '<plug>(asterisk-gz#)')

          vim.g.floaterm_opener = 'edit'
          map('n', '<leader>.', ':FloatermNew lf<cr>')

          map('n', '[d', function() vim.diagnostic.goto_prev() end)
          map('n', ']d', function() vim.diagnostic.goto_next() end)
          map('n', '[e', function()
            vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })
          end)
          map('n', ']e', function()
            vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })
          end)

          require'Comment'.setup()
          require'nvim-autopairs'.setup()

          require'dressing'.setup({
            input = {
              insert_only = false,
            },

            select = {
              telescope = require'telescope.themes'.get_dropdown({
                initial_mode = 'normal',
              }),
            },
          })

          ${cfg.customRC}
        EOF
      '';

      configure.packages.ddd = {
        start = cfg.plugins;
        opt = [ ];
      };

      extraMakeWrapperArgs = ''
        --suffix PATH : "${lib.makeBinPath (cfg.packages)}"
      '';
    };

    plugins = with neovimPkgs.vimPlugins; [
      abolish
      asterisk
      autopairs
      bufdelete
      comment
      dressing
      floaterm
      plenary
      repeat
      sleuth
      surround
      tmux-navigator
      unimpaired
    ];
  };
}

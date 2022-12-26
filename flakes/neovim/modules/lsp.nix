{ config, lib, neovimPkgs, ... }:

let
  cfg = config.programs.ddd.neovim.lsp;

  setupClient = name: config: ''
    require'lspconfig'.${name}.setup {
      capabilities = lsp_capabilities,

      on_attach = function(client, bufnr)
        lsp_on_attach(client, bufnr)
        ${config.onAttach}
      end,

      ${lib.optionalString (config.rootDir != "") "root_dir = ${config.rootDir},"}
      ${lib.optionalString (config.cmd != []) "cmd = ${neovimPkgs.lib.ddd.toLua config.cmd},"}
      ${lib.optionalString (config.settings != {}) "settings = ${neovimPkgs.lib.ddd.toLua config.settings},"}
    }
  '';

in
{
  options.programs.ddd.neovim.lsp = {
    client = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          rootDir = lib.mkOption {
            type = lib.types.lines;
            default = "";
          };

          cmd = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
          };

          settings = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };

          onAttach = lib.mkOption {
            type = lib.types.lines;
            default = "";
          };
        };
      });
      default = { };
    };

    format.exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };

    null-ls.sources = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
  };

  config.programs.ddd.neovim.customRC = ''
    local lsp_capabilities = require'cmp_nvim_lsp'.default_capabilities()

    local lsp_on_attach = function(client, bufnr)
      local map = map_with({ buffer = bufnr })

      map('n', 'K', vim.lsp.buf.hover)
      map('n', '<leader>cr', vim.lsp.buf.rename)
      map('n', '<leader>c.', vim.lsp.buf.code_action)

      map('n', 'gd', function()
        telescope_builtin.lsp_definitions({
          initial_mode = 'normal',
        })
      end)

      map('n', 'gD', function()
        telescope_builtin.lsp_references({
          initial_mode = 'normal',
          show_line = false,
        })
      end)

      local format_exclude = ${
      neovimPkgs.lib.ddd.toLua
        (builtins.listToAttrs
          (map (name: { inherit name; value = true; })
            cfg.format.exclude))
      }

      map('n', '<leader>cf', function()
        vim.lsp.buf.format {
          filter = function(client)
            return not format_exclude[client.name]
          end,
        }
      end)

      require'lsp_signature'.on_attach(nil, bufnr)
    end

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList setupClient cfg.client)}

    require'null-ls'.setup {
      cmd = { '${config.programs.ddd.neovim.package}/bin/nvim' },
      root_dir = require'null-ls.utils'.root_pattern(".git"),
      diagnostics_format = "[#{s}:#{c}] #{m}",
      on_attach = lsp_on_attach,

      sources = {
        ${lib.strings.concatStringsSep ",\n" cfg.null-ls.sources}
      },
    }
  '';

  config.programs.ddd.neovim.plugins = with neovimPkgs.vimPlugins; [
    lsp-signature
    lspconfig
    null-ls
  ];
}

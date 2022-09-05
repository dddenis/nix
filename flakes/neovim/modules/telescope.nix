{ pkgs, ... }:

{
  config.programs.ddd.neovim.customRC = ''
    local telescope = require'telescope'

    telescope.setup{
      defaults = {
        dynamic_preview_title = true,
        layout_strategy = 'vertical',
        layout_config = {
          vertical = {
            preview_height = 0.7,
          },
        },
      },
    }

    telescope.load_extension('fzf')

    local telescope_builtin = require('telescope.builtin')
    local telescope_utils = require('telescope.utils')

    map('n', '<leader>\''', telescope_builtin.resume)
    map('n', '<leader><leader>', function()
      telescope_builtin.find_files({
        find_command = { "fd", "--type", "f", "--color", "never", "--hidden" }
      })
    end)
    map('n', '<leader>fr', telescope_builtin.oldfiles)
    map('n', '<leader>,', telescope_builtin.buffers)
    map('n', '<leader>s*', telescope_builtin.grep_string)
    map('n', '<leader>sp', telescope.extensions.live_grep_args.live_grep_args)
    map('n', '<leader>s.', function()
      telescope_builtin.live_grep({ cwd = telescope_utils.buffer_dir() })
    end)
    map('n', '<leader>s,', function()
      telescope_builtin.live_grep({
        cwd = { vim.fn.input("Enter the directory to search: ", "", "file") }
      })
    end)
  '';

  config.programs.ddd.neovim.plugins = with pkgs.ddd.vimPlugins; [
    telescope
    telescope-fzf-native
    telescope-live-grep-args
  ];
}

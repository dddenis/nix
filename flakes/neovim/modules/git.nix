{ pkgs, ... }:

{
  config.programs.ddd.neovim.customRC = ''
    map('n', '<leader>gm', '<plug>(MergetoolToggle)')

    mergetool_map_opts = {
      expr = true,
      replace_keycodes = false,
    }
    map('n', '<leader>gh', '&diff ? "<plug>(MergetoolDiffExchangeLeft)" : "<leader>gh"', mergetool_map_opts)
    map('n', '<leader>gl', '&diff ? "<plug>(MergetoolDiffExchangeRight)" : "<leader>gl"', mergetool_map_opts)
    map('n', '<leader>gj', '&diff ? "<plug>(MergetoolDiffExchangeDown)" : "<leader>gj"', mergetool_map_opts)
    map('n', '<leader>gk', '&diff ? "<plug>(MergetoolDiffExchangeUp)" : "<leader>gk"', mergetool_map_opts)

    require'gitsigns'.setup({
      on_attach = function(bufnr)
        local gs = package.loaded.gitsigns
        local map = map_with({ buffer = bufnr })

        map('n', ']c', function()
          if vim.wo.diff then return ']c' end
          vim.schedule(function() gs.next_hunk() end)
          return '<Ignore>'
        end, { expr = true })

        map('n', '[c', function()
          if vim.wo.diff then return '[c' end
          vim.schedule(function() gs.prev_hunk() end)
          return '<Ignore>'
        end, { expr = true })

        map({ 'n', 'v' }, '<leader>gr', gs.reset_hunk)
        map({ 'n', 'v' }, '<leader>gs', gs.stage_hunk)
        map('n', '<leader>gu', gs.undo_stage_hunk)
        map('n', '<leader>gp', gs.preview_hunk)
        map('n', '<leader>gS', gs.stage_buffer)
        map('n', '<leader>gR', gs.reset_buffer)
        map('n', '<leader>gb', function() gs.blame_line{ full = true } end)
        map('n', '<leader>gtb', gs.toggle_current_line_blame)
        map('n', '<leader>gd', gs.diffthis)
        map('n', '<leader>gD', function() gs.diffthis('~') end)
        map('n', '<leader>gtd', gs.toggle_deleted)

        map({'o', 'x'}, 'ih', ':<C-u>Gitsigns select_hunk<cr>')
      end,
    })
  '';

  config.programs.ddd.neovim.plugins = with pkgs.ddd.vimPlugins; [
    fugitive
    gitsigns
    mergetool
  ];
}

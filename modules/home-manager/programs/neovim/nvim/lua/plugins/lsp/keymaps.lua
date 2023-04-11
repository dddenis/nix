local M = {}

M._keys = nil

function M.get()
    if not M._keys then
        local function source_action()
            vim.lsp.buf.code_action({
                context = {
                    only = { "source" },
                    diagnostics = {},
                },
            })
        end

        M._keys = {
            {
                "gd",
                "<cmd>Telescope lsp_definitions initial_mode=normal<cr>",
                desc = "Go to Definition",
                has = "definition",
            },
            { "gD", "<cmd>Telescope lsp_references initial_mode=normal show_line=false<cr>", desc = "References" },
            { "gt", "<cmd>Telescope lsp_type_definitions<cr>", desc = "Goto Type Definition" },
            { "K", vim.lsp.buf.hover, desc = "Hover" },
            { "]d", M.diagnostic_goto(true), desc = "Next Diagnostic" },
            { "[d", M.diagnostic_goto(false), desc = "Prev Diagnostic" },
            { "]e", M.diagnostic_goto(true, "ERROR"), desc = "Next Error" },
            { "[e", M.diagnostic_goto(false, "ERROR"), desc = "Prev Error" },
            { "<leader>cf", M.format, desc = "Format Document", has = "documentFormatting" },
            { "<leader>cf", M.format, desc = "Format Range", mode = "v", has = "documentRangeFormatting" },
            { "<leader>cr", vim.lsp.buf.rename, desc = "Rename", has = "rename" },
            { "<leader>c.", vim.lsp.buf.code_action, desc = "Code Action", mode = { "n", "v" }, has = "codeAction" },
            { "<leader>c/", source_action, desc = "Source Action", has = "codeAction" },
        }
    end
    return M._keys
end

function M.on_attach(client, buffer)
    local Keys = require("lazy.core.handler.keys")
    local keymaps = {}

    for _, value in ipairs(M.get()) do
        local keys = Keys.parse(value)
        if keys[2] == vim.NIL or keys[2] == false then
            keymaps[keys.id] = nil
        else
            keymaps[keys.id] = keys
        end
    end

    for _, keys in pairs(keymaps) do
        if not keys.has or client.server_capabilities[keys.has .. "Provider"] then
            local opts = Keys.opts(keys)
            opts.has = nil
            opts.silent = opts.silent ~= false
            opts.buffer = buffer
            vim.keymap.set(keys.mode or "n", keys[1], keys[2], opts)
        end
    end
end

function M.diagnostic_goto(next, severity)
    local go = next and vim.diagnostic.goto_next or vim.diagnostic.goto_prev
    severity = severity and vim.diagnostic.severity[severity] or nil
    return function()
        go({ severity = severity })
    end
end

function M.format()
    local buf = vim.api.nvim_get_current_buf()
    local ft = vim.bo[buf].filetype
    local have_nls = #require("null-ls.sources").get_available(ft, "NULL_LS_FORMATTING") > 0

    vim.lsp.buf.format({
        bufnr = buf,
        filter = function(client)
            if have_nls then
                return client.name == "null-ls"
            end
            return client.name ~= "null-ls"
        end,
    })
end

return M

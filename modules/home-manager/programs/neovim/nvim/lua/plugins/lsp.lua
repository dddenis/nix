local function organize_imports()
    vim.lsp.buf.code_action({
        context = { only = { "source.organizeImports" }, diagnostics = {} },
        apply = true,
    })
end

local function source_action()
    vim.lsp.buf.code_action({
        context = { only = { "source" }, diagnostics = {} },
    })
end

local function jump_to_error(count)
    return function()
        vim.diagnostic.jump({ count = count, severity = vim.diagnostic.severity.ERROR })
    end
end

local function on_attach(args)
    local client = assert(vim.lsp.get_client_by_id(args.data.client_id))

    -- `method` limits a keymap to servers that support it
    local function map(mode, lhs, rhs, desc, method)
        if method and not client:supports_method(method, args.buf) then
            return
        end
        vim.keymap.set(mode, lhs, rhs, { buffer = args.buf, silent = true, desc = desc })
    end

    map(
        "n",
        "gd",
        "<cmd>Telescope lsp_definitions initial_mode=normal<cr>",
        "Go to Definition",
        "textDocument/definition"
    )
    map("n", "gD", "<cmd>Telescope lsp_references initial_mode=normal show_line=false<cr>", "References")
    map("n", "gy", "<cmd>Telescope lsp_type_definitions<cr>", "Go to Type Definition")
    map("n", "]e", jump_to_error(1), "Next Error")
    map("n", "[e", jump_to_error(-1), "Prev Error")
    map("n", "<leader>cr", vim.lsp.buf.rename, "Rename", "textDocument/rename")
    map({ "n", "v" }, "<leader>c.", vim.lsp.buf.code_action, "Code Action", "textDocument/codeAction")
    map("n", "<leader>c/", source_action, "Source Action", "textDocument/codeAction")
    map("n", "<leader>ci", organize_imports, "Organize Imports", "textDocument/codeAction")

    if client.name == "eslint" then
        map("n", "<leader>ce", "<cmd>LspEslintFixAll<cr>", "Fix All")
    end
end

return {
    {
        -- server defaults; overrides live in after/lsp/<server>.lua
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            vim.lsp.log.set_level("off")

            vim.diagnostic.config({
                float = { source = true },
                jump = {
                    on_jump = function(diagnostic, bufnr)
                        if diagnostic then
                            vim.diagnostic.open_float({ bufnr = bufnr, scope = "cursor", focus = false })
                        end
                    end,
                },
            })

            vim.api.nvim_create_autocmd("LspAttach", { callback = on_attach })

            vim.lsp.enable({
                "astro",
                "bashls",
                "clojure_lsp",
                "elixirls",
                "eslint",
                "gleam",
                "gopls",
                "hls",
                "jsonls",
                "lua_ls",
                "nil_ls",
                "pyright",
                "rust_analyzer",
                "svelte",
                "terraformls",
                "ts_ls",
                "tsc",
            })
        end,
    },
    { "folke/lazydev.nvim", ft = "lua", opts = {} },
}

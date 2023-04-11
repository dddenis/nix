return {
    "neovim/nvim-lspconfig",
    opts = {
        servers = {
            rust_analyzer = {
                settings = {
                    rust_analyzer = {
                        completion = {
                            callable = {
                                snippets = "none",
                            },
                        },
                    },
                },
            },
        },
    },
}

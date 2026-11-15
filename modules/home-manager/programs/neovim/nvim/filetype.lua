vim.filetype.add({
    filename = {
        [".env"] = "sh.dotenv",
    },
    pattern = {
        [".+%.env"] = "sh.dotenv",
        -- outrank the built-in `env` filetype, which matches at the default priority
        ["%.env%..+"] = { "sh.dotenv", { priority = 10 } },
    },
})

function P(v)
    print(vim.inspect(v))
    return v
end

function MapWith(options)
    return function(mode, lhs, rhs, opts)
        vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", options or {}, opts or {}))
    end
end

-- Map = MapWith({ silent = true })
Map = vim.keymap.set

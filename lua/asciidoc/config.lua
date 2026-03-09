local defaults = {
    treesitter = {
        auto_install = false,
        -- Override grammar source (e.g. local fork with fixes)
        -- Example: { url = "/path/to/fork", branch = "my-fix" }
        asciidoc = nil,
        asciidoc_inline = nil,
    },
}

local user_config = vim.g.asciidoc or {}
return vim.tbl_deep_extend('force', defaults, user_config)

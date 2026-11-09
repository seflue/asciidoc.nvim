local defaults = {
    treesitter = {
        auto_install = false,
        -- Override grammar source (e.g. local fork with fixes)
        -- Example: { url = "/path/to/fork", branch = "my-fix" }
        asciidoc = nil,
        asciidoc_inline = nil,
    },
    lsp = {
        -- Auto-enable the asciidoc LSP client when this plugin loads.
        -- Set to false if you prefer to call `vim.lsp.enable("asciidoc")` yourself.
        enable = true,
    },
    textobjects = {
        -- Map `iS` / `aS` (inside / around section) in AsciiDoc buffers.
        enable = true,
    },
}

local user_config = vim.g.asciidoc or {}
return vim.tbl_deep_extend('force', defaults, user_config)

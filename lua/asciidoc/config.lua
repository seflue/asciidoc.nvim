local defaults = {
    treesitter = {
        auto_install = false,
        -- Override grammar source (e.g. fork with fixes). Without an
        -- override the parsers are pinned to the commit the bundled queries
        -- are written for (lua/asciidoc/grammar.lua). A url or branch
        -- override drops that pin unless it also sets a revision; a path
        -- override (local checkout, built as it is) always drops it.
        -- Example: { url = "https://github.com/you/tree-sitter-asciidoc", branch = "my-fix" }
        --          { path = "/path/to/tree-sitter-asciidoc" }
        --          { revision = "<full commit SHA>" }
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
    motions = {
        -- Map the section motions in AsciiDoc buffers.
        enable = true,
        -- Key per motion; false leaves that one unmapped.
        keys = {
            next = "]]",
            prev = "[[",
            next_sibling = "][",
            prev_sibling = "[]",
            parent = "[u",
            next_parent = "]u",
        },
    },
    folds = {
        -- Fold sections and blocks with Tree-sitter (`foldmethod=expr`).
        -- Which folds start closed is up to your `foldlevel`.
        enable = true,
    },
    conceal = {
        -- Hide the delimiters of *strong*, _italic_, `monospace` and #highlighted#
        -- text where `conceallevel` hides concealed text.
        enable = true,
    },
}

local user_config = vim.g.asciidoc or {}
return vim.tbl_deep_extend('force', defaults, user_config)

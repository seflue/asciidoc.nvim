# asciidoc.nvim

![Latest release](https://img.shields.io/github/v/release/seflue/asciidoc.nvim)

AsciiDoc support for Neovim: syntax highlighting, folding, section text
objects and motions, concealed inline markup, spellcheck for prose only, and a ready-made
setup for the [asciidoc-lsp](https://github.com/seflue/asciidoc-lsp) language
server (navigation, completion, hover, diagnostics, rename).

## Requirements

- Neovim 0.11 or later
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
- a current [asciidoc-lsp](https://github.com/seflue/asciidoc-lsp/releases) on
  your `$PATH` (`:checkhealth asciidoc` reports one that is too old)
- `inotify-tools` on Linux (recommended)

## Installation

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'seflue/asciidoc.nvim',
    ft = 'asciidoc',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    init = function()
        vim.g.asciidoc = { treesitter = { auto_install = true } }
    end,
}
```

With `auto_install` the plugin installs and updates the two parsers for you.
Without it, run `:TSInstall asciidoc asciidoc_inline` once and
`:TSUpdate asciidoc asciidoc_inline` after each plugin update.
See [INSTALL.md](INSTALL.md) for more.

## Configuration

Set `vim.g.asciidoc` before the plugin loads. No `setup()` call is needed.
These are the defaults:

```lua
vim.g.asciidoc = {
    treesitter = {
        auto_install = false,  -- install and update the parsers
        asciidoc = nil,        -- grammar source override, see :help asciidoc.nvim-parser-pin
        asciidoc_inline = nil,
    },
    lsp = {
        enable = true,         -- start asciidoc-lsp for AsciiDoc buffers
    },
    textobjects = {
        enable = true,         -- iS / aS select a section
    },
    motions = {
        enable = true,         -- jump between sections, see :help asciidoc.nvim-motions
        keys = {               -- set one to false to leave it unmapped
            next = "]]", prev = "[[",                -- next / previous section
            next_sibling = "][", prev_sibling = "[]", -- same level, same parent
            parent = "[u", next_parent = "]u",       -- enclosing / next at its level
        },
    },
    folds = {
        enable = true,         -- fold sections and blocks (foldmethod=expr)
    },
    conceal = {
        enable = true,         -- hide *strong*, _italic_, `mono` and #mark# delimiters
    },
}
```

To use another server binary:

```lua
vim.lsp.config('asciidoc', { cmd = { '/path/to/asciidoc-lsp' } })
```

`:AsciidocDebug` shows how the server resolves the position under the
cursor.

`:AsciidocPreview` opens a live preview of the buffer in the browser (the
server needs `asciidoctor` in `$PATH`). The page follows the cursor, also
when you move to another AsciiDoc buffer. `:AsciidocPreview part` shows
only the part of the document that the buffer contributes (for example an
included file) instead of the complete document; `:AsciidocPreview
document` is the default. The full reference is in
`:help asciidoc.nvim`.

`:AsciidocPreview debug on` makes the server number each cursor line and
the page report how it placed it; `:AsciidocPreview debug show` lists both
side by side, `debug off` switches it off again.

`:AsciidocPreviewStop` stops the page from following the cursor. The page
stays open and the preview server keeps running; `:AsciidocPreview` makes
it follow again.

The other way round, scrolling the page scrolls the window to the same
place (in a file of includes, the cursor goes to the include of the chapter
you read), and a double-click on a block in the page opens its source line,
also in an included file. Both can be switched off in the page.

## Health check

```vim
:checkhealth asciidoc
```

It checks the Neovim and asciidoc-lsp versions, the parsers and queries, and
file watching.

## License

Apache License 2.0, see [LICENSE](LICENSE).

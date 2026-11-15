# Installation

## Requirements

- Neovim 0.11 or later
- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter) to
  install the parsers
- a current [asciidoc-lsp](https://github.com/seflue/asciidoc-lsp/releases) on
  your `$PATH` (`:checkhealth asciidoc` reports one that is too old)
- `inotify-tools` on Linux, so changes on disk reach the language server

## lazy.nvim

```lua
{
    'seflue/asciidoc.nvim',
    ft = 'asciidoc',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
}
```

The plugin enables the language server itself. Install the parsers once from
an AsciiDoc buffer:

```vim
:TSInstall asciidoc asciidoc_inline
```

After each plugin update, update the parsers to the grammar the bundled
queries are written for, and restart Neovim:

```vim
:TSUpdate asciidoc asciidoc_inline
```

With `treesitter = { auto_install = true }` the plugin does both when it loads.

## With overrides

```lua
{
    'seflue/asciidoc.nvim',
    ft = 'asciidoc',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    init = function()
        vim.g.asciidoc = {
            treesitter = { auto_install = true },
        }
        vim.lsp.config('asciidoc', {
            cmd = { '/custom/path/asciidoc-lsp' },
        })
    end,
}
```

## Local checkout

Point lazy.nvim at a clone with `dir`:

```lua
{
    dir = '~/path/to/asciidoc.nvim',
    ft = 'asciidoc',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
}
```

## Verify

```vim
:checkhealth asciidoc
```

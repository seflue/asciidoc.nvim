# Installation Guide

## Lazy.nvim — Local Development

Replace the existing `asciidoc-treesitter.lua` plugin spec with:

```lua
-- ~/.config/nvims-sf-LazyVim/lua/plugins/asciidoc.lua
return {
  {
    dir = '/home/sebflu/scratchpad/research/asciidoc_nvim/asciidoc.nvim',
    ft = 'asciidoc',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    init = function()
      vim.lsp.enable('asciidoc')
    end,
  },
}
```

## Migration Steps

### 1. Create new plugin spec

Create `~/.config/nvims-sf-LazyVim/lua/plugins/asciidoc.lua` with the content above.

### 2. Remove old treesitter spec

Delete or disable `~/.config/nvims-sf-LazyVim/lua/plugins/asciidoc-treesitter.lua`.

### 3. Remove after/queries (now bundled in plugin)

```bash
rm -rf ~/.config/nvims-sf-LazyVim/after/queries/asciidoc/
rm -rf ~/.config/nvims-sf-LazyVim/after/queries/asciidoc_inline/
```

### 4. Update ftplugin

Replace `~/.config/nvims-sf-LazyVim/ftplugin/asciidoc.lua` with:

```lua
-- Buffer settings are now handled by the plugin.
-- Only keep project-specific overrides here if needed.
```

The plugin's `ftplugin/asciidoc.lua` sets `iskeyword`, `commentstring`, `spell`, and `wrap`.
The plugin's `lsp/asciidoc.lua` handles LSP start (no more hardcoded dev path).

### 5. Restart Neovim and install parsers

```vim
:TSInstall asciidoc asciidoc_inline
```

After each plugin update, open an AsciiDoc file, update the parsers to the
grammar commit the bundled queries are written for, and restart Neovim:

```vim
:TSUpdate asciidoc asciidoc_inline
```

With `treesitter = { auto_install = true }` the plugin does this when it loads.

## Lazy.nvim — Published (future)

```lua
{
    'user/asciidoc.nvim',
    ft = 'asciidoc',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    init = function()
        vim.lsp.enable('asciidoc')
    end,
}
```

## With overrides

```lua
{
    'user/asciidoc.nvim',
    ft = 'asciidoc',
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    init = function()
        vim.g.asciidoc = {
            treesitter = { auto_install = true },
        }
        vim.lsp.config('asciidoc', {
            cmd = { '/custom/path/asciidoc-lsp' },
        })
        vim.lsp.enable('asciidoc')
    end,
}
```

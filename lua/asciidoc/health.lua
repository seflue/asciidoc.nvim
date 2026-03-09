local M = {}

function M.check()
    vim.health.start('asciidoc.nvim')

    -- 1. Neovim version
    if vim.fn.has('nvim-0.11') == 1 then
        vim.health.ok('Neovim >= 0.11')
    else
        vim.health.error('Neovim >= 0.11 required', {
            'Update Neovim to 0.11 or later',
        })
    end

    -- 2. asciidoc-lsp binary
    if vim.fn.executable('asciidoc-lsp') == 1 then
        local result = vim.fn.system({ 'asciidoc-lsp', '--version' })
        local version = vim.trim(result)
        vim.health.ok('asciidoc-lsp found: ' .. version)
    else
        vim.health.error('asciidoc-lsp not found in $PATH', {
            'Install via: cargo install asciidoc-lsp',
            'Or download from GitHub Releases',
        })
    end

    -- 3. Treesitter ABI version
    local ts_abi = vim.treesitter.language_version
    if ts_abi then
        vim.health.ok('Treesitter ABI version: ' .. ts_abi)
    else
        vim.health.warn('Could not determine Treesitter ABI version')
    end

    -- 4. Parser: asciidoc
    local ok_asciidoc = pcall(vim.treesitter.language.inspect, 'asciidoc')
    if ok_asciidoc then
        vim.health.ok('Treesitter parser `asciidoc` installed')
    else
        vim.health.warn('Treesitter parser `asciidoc` not installed', {
            'Run :TSInstall asciidoc',
        })
    end

    -- 5. Parser: asciidoc_inline
    local ok_inline = pcall(vim.treesitter.language.inspect, 'asciidoc_inline')
    if ok_inline then
        vim.health.ok('Treesitter parser `asciidoc_inline` installed')
    else
        vim.health.warn('Treesitter parser `asciidoc_inline` not installed', {
            'Run :TSInstall asciidoc_inline',
        })
    end

    -- 6. nvim-treesitter plugin (optional)
    local has_ts = pcall(require, 'nvim-treesitter')
    if has_ts then
        vim.health.ok('nvim-treesitter plugin found')
    else
        vim.health.warn('nvim-treesitter not installed (optional)', {
            'Install nvim-treesitter for :TSInstall support',
        })
    end
end

return M

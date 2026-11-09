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

    -- 6. Queries against the installed parsers. A parser built from
    -- another grammar commit loads fine, but a query naming a node it
    -- lacks fails to parse and disables that query. Each file is parsed
    -- on its own so the report names the culprit.
    local grammar = require('asciidoc.grammar')
    local update_advice = 'Run :TSUpdate asciidoc asciidoc_inline and restart Neovim'
    local query_errors = 0
    local queries_checked = 0
    for _, lang in ipairs(grammar.languages) do
        if pcall(vim.treesitter.language.add, lang) then
            local names = {}
            for _, path in ipairs(vim.api.nvim_get_runtime_file('queries/' .. lang .. '/*.scm', true)) do
                names[vim.fn.fnamemodify(path, ':t:r')] = true
            end
            for _, name in ipairs(vim.tbl_keys(names)) do
                for _, file in ipairs(vim.treesitter.query.get_files(lang, name)) do
                    queries_checked = queries_checked + 1
                    local source = table.concat(vim.fn.readfile(file), '\n')
                    local ok, err = pcall(vim.treesitter.query.parse, lang, source)
                    if not ok then
                        query_errors = query_errors + 1
                        vim.health.error(
                            string.format('%s does not load with the installed `%s` parser: %s', file, lang,
                                tostring(err):match('[^\n]*')),
                            {
                                'The parser was built from another tree-sitter-asciidoc commit than the queries expect',
                                update_advice,
                            }
                        )
                    end
                end
            end
        end
    end
    if queries_checked > 0 and query_errors == 0 then
        vim.health.ok('Queries load with the installed parsers')
    end

    -- 7. Revision nvim-treesitter built each parser from, against the
    -- pinned (or overridden) one. Only a warning: the queries may still
    -- load. Skipped for parsers nvim-treesitter did not build and for
    -- overrides without a revision.
    for _, lang in ipairs(grammar.languages) do
        local expected = grammar.install_info(lang).revision
        local built = grammar.installed_revision(lang)
        if expected and built then
            local message = string.format('`%s` parser built from %s', lang, built)
            if built == expected then
                vim.health.ok(message)
            else
                vim.health.warn(message .. ', expected ' .. expected, { update_advice })
            end
        end
    end

    -- 8. nvim-treesitter plugin (optional)
    local has_ts = pcall(require, 'nvim-treesitter')
    if has_ts then
        vim.health.ok('nvim-treesitter plugin found')
    else
        vim.health.warn('nvim-treesitter not installed (optional)', {
            'Install nvim-treesitter for :TSInstall support',
        })
    end

    -- 9. Loaded asciidoc buffers with asciidoc-lsp attached. :checkhealth
    -- runs in its own tab, so every such buffer is reported, not the current.
    vim.health.start('asciidoc.nvim: language server')
    local reported = false
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local clients = vim.lsp.get_clients({ bufnr = bufnr, name = 'asciidoc' })
        if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].filetype == 'asciidoc' and #clients > 0 then
            reported = true
            local path = vim.api.nvim_buf_get_name(bufnr)
            local attached = {}
            for _, client in ipairs(clients) do
                attached[#attached + 1] =
                    string.format('%s (root_dir: %s)', client.name, client.root_dir or 'none')
            end
            vim.health.ok(path .. ': ' .. table.concat(attached, ', '))
            local real = vim.uv.fs_realpath(path)
            if real and real ~= path then
                vim.health.warn(path .. ' resolves to ' .. real, {
                    'asciidoc-lsp may index this file under its real path;'
                        .. ' if navigation fails here, open the file by its real path',
                })
            end
        end
    end
    if not reported then
        vim.health.info('No loaded asciidoc buffer has asciidoc-lsp attached')
    end

    -- 10. File watching backend. On Linux, Neovim watches with inotifywait
    -- if it is executable, else with a fallback that reports
    -- no changes in subdirectories.
    if vim.fn.has('linux') == 1 then
        if vim.fn.executable('inotifywait') == 1 then
            vim.health.ok('inotifywait found: changes on disk reach asciidoc-lsp')
        else
            vim.health.warn('inotifywait not found: asciidoc-lsp misses changes on disk in subdirectories', {
                'Install inotify-tools',
            })
        end
    end
end

return M

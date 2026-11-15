local M = {}

M.min_server_version = '0.7.0'
M.releases_url = 'https://github.com/seflue/asciidoc-lsp/releases'

local function parse_triple(text)
    local major, minor, patch = text:match('^(%d+)%.(%d+)%.(%d+)')
    if not major then
        return nil
    end
    return { tonumber(major), tonumber(minor), tonumber(patch) }
end

local function at_least(version, minimum)
    for i = 1, 3 do
        if version[i] ~= minimum[i] then
            return version[i] > minimum[i]
        end
    end
    return true
end

--- Check the version `<cmd> --version` prints against `min_server_version`.
--- The server prints `asciidoc-lsp <version>`: `X.Y.Z` for a release, and
--- `X.Y.Z-<n>-g<sha>[-dirty]` for a local build, which is `n` commits after
--- `X.Y.Z`. Such a build passes when `X.Y.Z` does; below that, whether it has
--- the needed features is unknown. Anything else (no `--version` in old
--- servers, a build without tags) cannot be compared.
function M.check_server_version(cmd)
    local minimum = parse_triple(M.min_server_version)
    local advice = {
        'asciidoc.nvim needs asciidoc-lsp >= ' .. M.min_server_version,
        'Download it from ' .. M.releases_url,
    }
    local argv = vim.list_extend(vim.deepcopy(cmd), { '--version' })
    local ok, result = pcall(function()
        return vim.system(argv, { text = true, stdin = '', timeout = 5000 }):wait()
    end)
    local output = ok and vim.trim((result.stdout or '') .. (result.stderr or '')) or ''
    local version = output:match('^asciidoc%-lsp%s+(%S+)')
    local parsed = version and parse_triple(version)
    if not parsed then
        vim.health.warn(
            'Could not read the asciidoc-lsp version from `' .. table.concat(argv, ' ') .. '`',
            vim.list_extend({ 'The server may be older than 0.7.0, which has no --version' }, advice)
        )
        return
    end
    local is_release = version:match('^%d+%.%d+%.%d+$') ~= nil
    local is_local_build = version:match('^%d+%.%d+%.%d+%-%d+%-g%x+') ~= nil
    if is_release and at_least(parsed, minimum) then
        vim.health.ok('asciidoc-lsp ' .. version .. ' found')
    elseif is_release then
        vim.health.error('asciidoc-lsp ' .. version .. ' is too old', advice)
    elseif is_local_build and at_least(parsed, minimum) then
        vim.health.ok('asciidoc-lsp ' .. version .. ' found (local build)')
    elseif is_local_build then
        vim.health.warn(
            'asciidoc-lsp ' .. version .. ' is a local build after ' .. table.concat(parsed, '.')
                .. '; cannot tell whether it is >= ' .. M.min_server_version,
            advice
        )
    else
        vim.health.warn('Unrecognized asciidoc-lsp version: ' .. version, advice)
    end
end

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

    -- 2. asciidoc-lsp binary: the configured server command, and its version
    local cmd = vim.lsp.config.asciidoc and vim.lsp.config.asciidoc.cmd
    if type(cmd) ~= 'table' or type(cmd[1]) ~= 'string' then
        vim.health.warn('The asciidoc-lsp command is not a plain command; version not checked')
    elseif vim.fn.executable(cmd[1]) ~= 1 then
        vim.health.error(cmd[1] .. ' not found', {
            'Download asciidoc-lsp from ' .. M.releases_url,
            'Or set the command: vim.lsp.config("asciidoc", { cmd = { "/path/to/asciidoc-lsp" } })',
        })
    else
        M.check_server_version(cmd)
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

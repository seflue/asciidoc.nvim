-- The tree-sitter-asciidoc commit the bundled queries are written for.
-- Single source of truth: the justfile reads `url` and `revision` from the
-- lines below to build the test parsers, so keep each on its own line.
-- `revision` must be the full SHA (nvim-treesitter cannot install from a
-- short one).

local M = {
    url = "https://github.com/seflue/tree-sitter-asciidoc",
    branch = "develop",
    revision = "f41d90c701187b46cb56759bf2bb04eedfab83c0",
}

--- nvim-treesitter `install_info` for `lang` (`asciidoc` or
--- `asciidoc_inline`), with the user's `config.treesitter[lang]` override.
--- A url or branch override drops the pin unless it names a revision too:
--- nvim-treesitter prefers `revision` to `branch`, and a fork may not
--- contain the pinned commit. A `path` override (local checkout) builds the
--- checkout as it is, so it never carries a revision.
function M.install_info(lang)
    local override = require("asciidoc.config").treesitter[lang] or {}
    local revision = override.revision
    if revision == nil and override.url == nil and override.branch == nil then
        revision = M.revision
    end
    if override.path ~= nil then
        revision = nil
    end
    return {
        url = override.url or M.url,
        branch = override.branch or M.branch,
        revision = revision,
        path = override.path,
        location = "tree-sitter-" .. lang,
    }
end

M.languages = { "asciidoc", "asciidoc_inline" }

--- The queries this plugin ships, per language.
M.queries = {
    asciidoc = { "highlights", "injections", "folds", "textobjects" },
    asciidoc_inline = { "highlights", "injections" },
}

--- Replace every bundled query that does not compile against the installed
--- parser with an empty one, and say once which parser to update. A parser
--- built from an older grammar lacks node types the queries name, and the
--- error a FileType autocmd raises when it compiles them (LazyVim checks for
--- a query without pcall) ends the chain that sets up the buffer. An installed
--- parser of another revision that the queries still fit is left alone, so
--- this checks compilation rather than the revision. Returns the queries that
--- were replaced, as `lang/name`.
function M.guard_queries()
    local replaced = {}
    for _, lang in ipairs(M.languages) do
        local ok, loaded = pcall(vim.treesitter.language.add, lang)
        if ok and loaded then
            for _, name in ipairs(M.queries[lang]) do
                if not pcall(vim.treesitter.query.get, lang, name) then
                    vim.treesitter.query.set(lang, name, "")
                    replaced[#replaced + 1] = lang .. "/" .. name
                end
            end
        end
    end
    if #replaced > 0 then
        vim.notify(
            "asciidoc.nvim: the installed parser is older than the bundled queries ("
                .. table.concat(replaced, ", ")
                .. "); run :TSUpdate asciidoc asciidoc_inline and restart Neovim",
            vim.log.levels.WARN
        )
    end
    return replaced
end

--- Revision nvim-treesitter recorded when it built `lang`, or nil when
--- nvim-treesitter is absent or did not build it.
function M.installed_revision(lang)
    local ok, ts_config = pcall(require, "nvim-treesitter.config")
    if not ok then
        return nil
    end
    local path = vim.fs.joinpath(ts_config.get_install_dir("parser-info"), lang .. ".revision")
    local file = io.open(path, "r")
    if not file then
        return nil
    end
    local revision = vim.trim(file:read("*a"))
    file:close()
    return revision
end

--- Through nvim-treesitter (main branch API): install missing parsers and
--- rebuild those built from another revision than `install_info` names.
--- On nvim-treesitter's master branch, which lacks that API, warn instead.
function M.auto_install()
    local ts = require("nvim-treesitter")
    if type(ts.get_installed) ~= "function" then
        vim.notify(
            "asciidoc.nvim: auto_install needs nvim-treesitter's main branch;"
                .. " install the parsers with :TSInstall asciidoc asciidoc_inline",
            vim.log.levels.WARN
        )
        return
    end
    local installed = ts.get_installed("parsers")
    local missing, stale = {}, {}
    for _, lang in ipairs(M.languages) do
        if not vim.list_contains(installed, lang) then
            missing[#missing + 1] = lang
        else
            local expected = M.install_info(lang).revision
            if expected and M.installed_revision(lang) ~= expected then
                stale[#stale + 1] = lang
            end
        end
    end
    if #missing > 0 then
        ts.install(missing)
    end
    if #stale > 0 then
        ts.update(stale)
    end
end

return M

-- The tree-sitter-asciidoc commit the bundled queries are written for.
-- Single source of truth: the justfile reads `url` and `revision` from the
-- lines below to build the test parsers, so keep each on its own line.
-- `revision` must be the full SHA (nvim-treesitter cannot install from a
-- short one).

local M = {
    url = "https://github.com/seflue/tree-sitter-asciidoc",
    branch = "develop",
    revision = "34e2923f0056da786cd1d873800a7a69dc0e1c25",
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

return M

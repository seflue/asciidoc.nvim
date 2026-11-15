local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

--- Create `<tmp>/real/doc.adoc` and a file symlink `<tmp>/link.adoc` to it.
--- A file symlink, because Neovim already resolves symlinked directories in
--- buffer names. Returns the canonical tmp root.
local function project_with_symlink()
    local tmp = vim.fn.tempname()
    vim.fn.mkdir(tmp .. "/real", "p")
    local root = assert(vim.uv.fs_realpath(tmp))
    vim.fn.writefile({}, root .. "/.asciidoctorconfig")
    vim.fn.writefile({ "= Doc", "", "Text." }, root .. "/real/doc.adoc")
    vim.uv.fs_symlink(root .. "/real/doc.adoc", root .. "/link.adoc")
    return root
end

local function checkhealth_lines()
    child.cmd("checkhealth asciidoc")
    return child.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function lines_matching(lines, needle)
    return vim.tbl_filter(function(line)
        return line:find(needle, 1, true) ~= nil
    end, lines)
end

T["lists attached buffers with client and root_dir"] = function()
    local root = project_with_symlink()
    helpers.edit_with_lsp(child, root .. "/real/doc.adoc")

    local lines = checkhealth_lines()
    expect.equality(#lines_matching(lines, "asciidoc.nvim: language server"), 1)
    local entry = lines_matching(lines, root .. "/real/doc.adoc")
    expect.equality(#entry, 1)
    expect.equality(entry[1]:find("OK", 1, true) ~= nil, true)
    expect.equality(entry[1]:find("asciidoc (root_dir: " .. root .. ")", 1, true) ~= nil, true)
    expect.equality(#lines_matching(lines, "resolves to"), 0)
end

T["warns when the buffer path is not the real path"] = function()
    local root = project_with_symlink()
    helpers.edit_with_lsp(child, root .. "/link.adoc")

    local lines = checkhealth_lines()
    local warning = lines_matching(lines, "resolves to")
    expect.equality(#warning, 1)
    expect.equality(warning[1]:find("WARNING", 1, true) ~= nil, true)
    expect.equality(warning[1]:find(root .. "/link.adoc", 1, true) ~= nil, true)
    expect.equality(warning[1]:find(root .. "/real/doc.adoc", 1, true) ~= nil, true)
end

--- Point the child's PATH at a fresh directory, with an executable
--- `inotifywait` in it if `with_inotifywait`.
local function path_with(with_inotifywait)
    local bin = vim.fn.tempname()
    vim.fn.mkdir(bin, "p")
    if with_inotifywait then
        vim.fn.writefile({ "#!/bin/sh" }, bin .. "/inotifywait")
        vim.uv.fs_chmod(bin .. "/inotifywait", tonumber("755", 8))
    end
    child.lua("vim.env.PATH = ...", { bin })
end

T["warns when inotifywait is missing"] = function()
    if vim.fn.has("linux") == 0 then
        MiniTest.skip("inotifywait only matters on Linux")
    end
    path_with(false)
    local warning = lines_matching(checkhealth_lines(), "inotifywait")
    expect.equality(#warning, 1)
    expect.equality(warning[1]:find("WARNING", 1, true) ~= nil, true)
end

T["reports inotifywait when present"] = function()
    if vim.fn.has("linux") == 0 then
        MiniTest.skip("inotifywait only matters on Linux")
    end
    path_with(true)
    local entry = lines_matching(checkhealth_lines(), "inotifywait")
    expect.equality(#entry, 1)
    expect.equality(entry[1]:find("OK", 1, true) ~= nil, true)
end

-- A parser older or newer than the grammar the queries are written for
-- loads fine, but a query naming a node it lacks fails to parse and
-- disables highlighting. A broken query file stands in for such a parser.
T["reports a query file the installed parser cannot load"] = function()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir .. "/queries/asciidoc", "p")
    local file = dir .. "/queries/asciidoc/highlights.scm"
    vim.fn.writefile({ "(no_such_node) @markup" }, file)
    child.lua("vim.opt.runtimepath:prepend(...)", { dir })

    local lines = checkhealth_lines()
    local errors = lines_matching(lines, file)
    expect.equality(#errors, 1)
    expect.equality(errors[1]:find("ERROR", 1, true) ~= nil, true)
    expect.equality(errors[1]:find("no_such_node", 1, true) ~= nil, true)
    expect.equality(#lines_matching(lines, ":TSUpdate asciidoc asciidoc_inline"), 1)
end

T["reports that the bundled queries load"] = function()
    local lines = checkhealth_lines()
    local ok = lines_matching(lines, "Queries load with the installed parsers")
    expect.equality(#ok, 1)
    expect.equality(ok[1]:find("OK", 1, true) ~= nil, true)
    expect.equality(#lines_matching(lines, "ERROR"), 0)
end

--- Stub nvim-treesitter's install directory in the child with a recorded
--- build revision per language, and set `config` as `vim.g.asciidoc`.
local function built_from(revisions, config)
    child.lua(
        [[
        local revisions, config, dir = ...
        vim.g.asciidoc = config
        package.loaded["asciidoc.config"] = nil
        vim.fn.mkdir(dir .. "/parser-info", "p")
        for lang, rev in pairs(revisions) do
            vim.fn.writefile({ rev }, dir .. "/parser-info/" .. lang .. ".revision")
        end
        package.preload["nvim-treesitter.config"] = function()
            return { get_install_dir = function(name) return dir .. "/" .. name end }
        end
    ]],
        { revisions, config or vim.empty_dict(), vim.fn.tempname() }
    )
end

local function pin()
    return child.lua_get([[require("asciidoc.grammar").revision]])
end

T["build revision"] = MiniTest.new_set()

T["build revision"]["warns when nvim-treesitter built a parser from another revision"] = function()
    built_from({ asciidoc = "develop", asciidoc_inline = pin() })
    local lines = checkhealth_lines()
    local warning = lines_matching(lines, "built from develop")
    expect.equality(#warning, 1)
    expect.equality(warning[1]:find("WARNING", 1, true) ~= nil, true)
    expect.equality(warning[1]:find("`asciidoc`", 1, true) ~= nil, true)
    expect.equality(warning[1]:find(pin(), 1, true) ~= nil, true)
    expect.equality(#lines_matching(lines, "`asciidoc_inline` parser built from"), 1)
    expect.equality(#lines_matching(lines, "`asciidoc_inline` parser built from " .. pin()), 1)
end

T["build revision"]["reports parsers built from the pin"] = function()
    built_from({ asciidoc = pin(), asciidoc_inline = pin() })
    local entries = lines_matching(checkhealth_lines(), "parser built from " .. pin())
    expect.equality(#entries, 2)
    expect.equality(entries[1]:find("OK", 1, true) ~= nil, true)
end

T["build revision"]["skips a parser overridden without a revision"] = function()
    built_from({ asciidoc = "develop" }, { treesitter = { asciidoc = { branch = "develop" } } })
    expect.equality(#lines_matching(checkhealth_lines(), "built from"), 0)
end

T["build revision"]["skips parsers nvim-treesitter did not build"] = function()
    built_from(vim.empty_dict())
    expect.equality(#lines_matching(checkhealth_lines(), "built from"), 0)
end

--- Make the child's server command a script that prints `output` (or
--- nothing) for `--version`.
local function server_printing(output)
    local script = vim.fn.tempname()
    vim.fn.writefile({ "#!/bin/sh", output and ("echo '" .. output .. "'") or "exit 0" }, script)
    vim.uv.fs_chmod(script, tonumber("755", 8))
    child.lua([[vim.lsp.config("asciidoc", { cmd = { ... } })]], { script })
end

T["server version"] = MiniTest.new_set()

T["server version"]["is OK from the minimum version on"] = function()
    server_printing("asciidoc-lsp 0.7.0")
    local entry = lines_matching(checkhealth_lines(), "asciidoc-lsp 0.7.0")
    expect.equality(#entry, 1)
    expect.equality(entry[1]:find("OK", 1, true) ~= nil, true)
end

T["server version"]["is OK for a local build after the minimum version"] = function()
    server_printing("asciidoc-lsp 0.7.0-3-gabc1234-dirty")
    local entry = lines_matching(checkhealth_lines(), "asciidoc-lsp 0.7.0-3-gabc1234-dirty")
    expect.equality(#entry, 1)
    expect.equality(entry[1]:find("OK", 1, true) ~= nil, true)
end

T["server version"]["is an error below the minimum version"] = function()
    server_printing("asciidoc-lsp 0.6.0")
    local lines = checkhealth_lines()
    local entry = lines_matching(lines, "asciidoc-lsp 0.6.0 is too old")
    expect.equality(#entry, 1)
    expect.equality(entry[1]:find("ERROR", 1, true) ~= nil, true)
    expect.equality(#lines_matching(lines, "asciidoc-lsp >= 0.7.0"), 1)
    expect.equality(#lines_matching(lines, "https://github.com/seflue/asciidoc-lsp/releases"), 1)
end

T["server version"]["warns for a local build after an older version"] = function()
    server_printing("asciidoc-lsp 0.6.0-42-gabc1234")
    local entry = lines_matching(checkhealth_lines(), "asciidoc-lsp 0.6.0-42-gabc1234")
    expect.equality(#entry, 1)
    expect.equality(entry[1]:find("WARNING", 1, true) ~= nil, true)
end

T["server version"]["warns when the output cannot be parsed"] = function()
    server_printing("something else")
    local lines = checkhealth_lines()
    local entry = lines_matching(lines, "Could not read the asciidoc-lsp version")
    expect.equality(#entry, 1)
    expect.equality(entry[1]:find("WARNING", 1, true) ~= nil, true)
    expect.equality(#lines_matching(lines, "asciidoc-lsp >= 0.7.0"), 1)
end

T["server version"]["warns when the server prints nothing"] = function()
    server_printing(nil)
    local entry = lines_matching(checkhealth_lines(), "Could not read the asciidoc-lsp version")
    expect.equality(#entry, 1)
    expect.equality(entry[1]:find("WARNING", 1, true) ~= nil, true)
end

T["says when no asciidoc buffer has the server attached"] = function()
    local lines = checkhealth_lines()
    expect.equality(#lines_matching(lines, "No loaded asciidoc buffer has asciidoc-lsp attached"), 1)
end

return T

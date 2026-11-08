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

T["says when no asciidoc buffer has the server attached"] = function()
    local lines = checkhealth_lines()
    expect.equality(#lines_matching(lines, "No loaded asciidoc buffer has asciidoc-lsp attached"), 1)
end

return T

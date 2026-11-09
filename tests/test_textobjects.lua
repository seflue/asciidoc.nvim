local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

T["@section.outer spans each section including nested ones and its anchor"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc")
    expect.equality(helpers.capture_ranges(child, "textobjects", "section.outer"), {
        { 2, 0, 14, 0 },
        { 11, 0, 14, 0 },
        { 15, 0, 19, 0 },
    })
end

T["@section.inner spans each section's content after the title"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc")
    expect.equality(helpers.capture_ranges(child, "textobjects", "section.inner"), {
        { 5, 0, 14, 0 },
        { 13, 0, 14, 0 },
        { 18, 0, 19, 0 },
    })
end

local sections = vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc"

--- Put the cursor on 1-based `line`, type `keys` and return the visual
--- selection as `{ mode, first_line, last_line }`.
local function select_lines(line, keys)
    child.api.nvim_win_set_cursor(0, { line, 0 })
    child.type_keys(keys)
    return child.lua_get([[{ vim.fn.mode(), math.min(vim.fn.line("v"), vim.fn.line(".")),
        math.max(vim.fn.line("v"), vim.fn.line(".")) }]])
end

T["section keymaps"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.cmd("edit " .. sections)
        end,
    },
})

T["section keymaps"]["vaS selects the innermost section linewise with its anchor"] = function()
    expect.equality(select_lines(6, "vaS"), { "V", 3, 14 })
    child.type_keys("<Esc>")
    expect.equality(select_lines(14, "vaS"), { "V", 12, 14 })
    child.type_keys("<Esc>")
    expect.equality(select_lines(17, "vaS"), { "V", 16, 19 })
end

T["section keymaps"]["viS selects the content below the title"] = function()
    expect.equality(select_lines(4, "viS"), { "V", 6, 14 })
    child.type_keys("<Esc>")
    expect.equality(select_lines(12, "viS"), { "V", 14, 14 })
    child.type_keys("<Esc>")
    expect.equality(select_lines(16, "viS"), { "V", 19, 19 })
end

T["section keymaps"]["daS deletes the nested section only"] = function()
    child.api.nvim_win_set_cursor(0, { 14, 0 })
    child.type_keys("daS")
    local lines = child.api.nvim_buf_get_lines(0, 0, -1, false)
    expect.equality(lines[11], "")
    expect.equality(lines[12], "")
    expect.equality(lines[13], "[[second,Second Part]]")
    expect.equality(#lines, 16)
end

T["section keymaps"]["dot repeats daS on the section under the cursor"] = function()
    child.api.nvim_win_set_cursor(0, { 14, 0 })
    child.type_keys("daS")
    child.api.nvim_win_set_cursor(0, { 13, 0 })
    child.type_keys(".")
    expect.equality(child.api.nvim_buf_get_lines(0, 0, -1, false), {
        "Preamble paragraph.",
        "",
        "[appendix]",
        "== First Section",
        "",
        "First paragraph.",
        "",
        "----",
        "listing",
        "----",
        "",
        "",
    })
end

T["section keymaps"]["dot outside any section does not repeat ciS"] = function()
    child.api.nvim_win_set_cursor(0, { 19, 0 })
    child.type_keys("ciS", "X", "<Esc>")
    expect.equality(child.api.nvim_buf_get_lines(0, 18, 19, false), { "X" })
    child.api.nvim_win_set_cursor(0, { 1, 0 })
    -- reports an error, as a failing built-in text object beeps
    expect.error(function()
        child.type_keys(".")
    end, "No section here")
    expect.equality(child.api.nvim_buf_get_lines(0, 0, 1, false), { "Preamble paragraph." })
    expect.equality(child.fn.mode(), "n")
end

T["section keymaps"]["yiS yanks the section content linewise"] = function()
    child.api.nvim_win_set_cursor(0, { 4, 0 })
    child.type_keys("yiS")
    expect.equality(child.fn.getregtype('"'), "V")
    expect.equality(
        child.fn.getreg('"'),
        "First paragraph.\n\n----\nlisting\n----\n\n=== Nested Section\n\nNested paragraph.\n"
    )
end

T["section keymaps"]["a count selects the enclosing section that many levels out"] = function()
    expect.equality(select_lines(14, "v2aS"), { "V", 3, 14 })
    child.type_keys("<Esc>")
    expect.equality(select_lines(14, "v2iS"), { "V", 6, 14 })
    child.type_keys("<Esc>")
    child.api.nvim_win_set_cursor(0, { 14, 0 })
    child.type_keys("3daS")
    expect.equality(#child.api.nvim_buf_get_lines(0, 0, -1, false), 19)
    child.type_keys("2daS")
    expect.equality(child.api.nvim_buf_get_lines(0, 0, 4, false), {
        "Preamble paragraph.",
        "",
        "",
        "[[second,Second Part]]",
    })
end

T["section keymaps"]["repeating aS in visual mode keeps the selected section"] = function()
    expect.equality(select_lines(6, "vaSaS"), { "V", 3, 14 })
    child.type_keys("<Esc>")
    expect.equality(select_lines(6, "viSiS"), { "V", 6, 14 })
end

T["section keymaps"]["outside any section the operator is cancelled"] = function()
    child.fn.setreg('"', "kept")
    child.api.nvim_win_set_cursor(0, { 1, 0 })
    child.type_keys("yaS")
    expect.equality(child.fn.getreg('"'), "kept")
    child.type_keys("caS")
    expect.equality(child.fn.mode(), "n")
    child.type_keys("daS")
    expect.equality(#child.api.nvim_buf_get_lines(0, 0, -1, false), 19)
end

T["iS on a section with only a heading cancels the operator"] = function()
    child.cmd("enew | setfiletype asciidoc")
    child.api.nvim_buf_set_lines(0, 0, -1, false, { "== Only a Heading", "" })
    child.api.nvim_win_set_cursor(0, { 1, 0 })
    child.fn.setreg('"', "kept")
    child.type_keys("yiS")
    expect.equality(child.fn.getreg('"'), "kept")
    child.type_keys("ciS")
    expect.equality(child.fn.mode(), "n")
    expect.equality(child.api.nvim_buf_get_lines(0, 0, -1, false), { "== Only a Heading", "" })
    child.type_keys("daS")
    expect.equality(child.api.nvim_buf_get_lines(0, 0, -1, false), { "" })
end

T["sentence objects is / as keep their built-in meaning"] = function()
    child.cmd("enew | setfiletype asciidoc")
    child.api.nvim_buf_set_lines(0, 0, -1, false, { "One two. Three four. Five." })
    for _, mode in ipairs({ "x", "o" }) do
        expect.equality(child.fn.maparg("is", mode), "")
        expect.equality(child.fn.maparg("as", mode), "")
    end
    child.api.nvim_win_set_cursor(0, { 1, 10 })
    child.type_keys("yis")
    expect.equality(child.fn.getreg('"'), "Three four.")
    child.type_keys("yas")
    expect.equality(child.fn.getreg('"'), "Three four. ")
end

T["section keymaps work alongside mini.ai"] = function()
    child.lua([[require("mini.ai").setup()]])
    child.cmd("edit " .. sections)
    expect.no_equality(child.fn.maparg("i", "x"), "")
    expect.equality(select_lines(14, "vaS"), { "V", 12, 14 })
    child.type_keys("<Esc>")
    expect.equality(select_lines(4, "viS"), { "V", 6, 14 })
    child.type_keys("<Esc>")
    child.api.nvim_win_set_cursor(0, { 14, 0 })
    child.type_keys("daS")
    expect.equality(#child.api.nvim_buf_get_lines(0, 0, -1, false), 16)
    -- mini.ai's own objects still work in the same buffer
    child.api.nvim_buf_set_lines(0, 0, 1, false, { 'say "hi there" now' })
    child.api.nvim_win_set_cursor(0, { 1, 0 })
    child.type_keys("yiq")
    expect.equality(child.fn.getreg('"'), "hi there")
end

T["section keymaps are not mapped when turned off"] = function()
    child.restart({
        "--cmd",
        "lua vim.g.asciidoc = { textobjects = { enable = false } }",
        "-u",
        vim.g.asciidoc_nvim_root .. "/tests/minimal_init.lua",
    })
    child.cmd("edit " .. sections)
    -- the ftplugin did run
    expect.equality(child.bo.commentstring, "// %s")
    for _, mode in ipairs({ "x", "o" }) do
        expect.equality(child.fn.maparg("iS", mode), "")
        expect.equality(child.fn.maparg("aS", mode), "")
    end
end

T["@section.outer spans a section past an attribute entry in its body"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/attribute_entries.adoc")
    expect.equality(helpers.capture_ranges(child, "textobjects", "section.outer"), {
        { 0, 0, 12, 0 },
        { 5, 0, 12, 0 },
        { 9, 0, 12, 0 },
    })
end

T["@section.outer finds the first section after a `:to` line in the header"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/attribute_header.adoc")
    expect.equality(helpers.capture_ranges(child, "textobjects", "section.outer"), {
        { 4, 0, 11, 0 },
        { 8, 0, 11, 0 },
    })
end

return T

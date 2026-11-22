local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local fixture = vim.g.asciidoc_nvim_root .. "/tests/fixtures/motions.adoc"

-- Titles in motions.adoc: 5 One, 9 One A, 13 One A x, 17 One B, 26 Two,
-- 35 Three (anchor and attribute from line 33; the leading comment on
-- line 32 stays in Two), 39 Three A,
-- 43 Four, 45 Four skipped, 49 Four B. Line 22 is a discrete heading,
-- line 29 a heading inside a listing block.

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.setup()
            child.cmd("edit " .. fixture)
        end,
        post_once = child.stop,
    },
})

--- Put the cursor on 1-based `line` (and `col`), type `keys` and return the
--- cursor as `{ line, col }`.
local function jump(line, keys, col)
    child.api.nvim_win_set_cursor(0, { line, col or 0 })
    child.type_keys(keys)
    return child.api.nvim_win_get_cursor(0)
end

T["]] jumps to the title of the next section of any level"] = function()
    expect.equality(jump(1, "]]"), { 5, 0 })
    expect.equality(jump(5, "]]"), { 9, 0 })
    expect.equality(jump(9, "]]"), { 13, 0 })
    expect.equality(jump(15, "]]"), { 17, 0 })
end

T["]] from body text lands in column 0 of the next title"] = function()
    expect.equality(jump(7, "]]", 3), { 9, 0 })
end

T["]] skips discrete headings and headings in delimited blocks"] = function()
    expect.equality(jump(19, "]]"), { 26, 0 })
    expect.equality(jump(26, "]]"), { 35, 0 })
end

T["]] past the last section keeps the cursor and reports it"] = function()
    child.api.nvim_win_set_cursor(0, { 49, 0 })
    expect.error(function()
        child.type_keys("]]")
    end, "No section here")
    expect.equality(child.api.nvim_win_get_cursor(0), { 49, 0 })
end

T["[[ jumps to the title of the previous section of any level"] = function()
    expect.equality(jump(9, "[["), { 5, 0 })
    expect.equality(jump(26, "[["), { 17, 0 })
    expect.equality(jump(35, "[["), { 26, 0 })
end

T["[[ in body text goes to the title of the section whose content began last"] = function()
    -- after One A x, inside One A's section range, before One B
    expect.equality(jump(15, "[[", 4), { 13, 0 })
    -- after the discrete heading
    expect.equality(jump(24, "[["), { 17, 0 })
    -- on the metadata above Three's title
    expect.equality(jump(33, "[["), { 26, 0 })
end

T["[[ before the first section keeps the cursor and reports it"] = function()
    child.api.nvim_win_set_cursor(0, { 5, 0 })
    expect.error(function()
        child.type_keys("[[")
    end, "No section here")
    expect.equality(child.api.nvim_win_get_cursor(0), { 5, 0 })
end

T["][ jumps to the next section with the same parent"] = function()
    expect.equality(jump(9, "]["), { 17, 0 })
    expect.equality(jump(5, "]["), { 26, 0 })
    expect.equality(jump(26, "]["), { 35, 0 })
end

T["[] jumps to the previous section with the same parent"] = function()
    expect.equality(jump(17, "[]"), { 9, 0 })
    expect.equality(jump(43, "[]"), { 35, 0 })
end

T["][ and [] in body text start from the section around the cursor"] = function()
    -- One's text before One A, and One A's text before One A x
    expect.equality(jump(7, "]["), { 26, 0 })
    expect.equality(jump(11, "]["), { 17, 0 })
    expect.equality(jump(19, "[]", 2), { 9, 0 })
    -- on the metadata above Three's title
    expect.equality(jump(33, "]["), { 43, 0 })
end

T["][ and [] follow the grammar's nesting across a skipped level"] = function()
    expect.equality(jump(45, "]["), { 49, 0 })
    expect.equality(jump(49, "[]"), { 45, 0 })
end

T["][ at the last and [] at the first sibling find no target"] = function()
    for _, case in ipairs({ { 17, "][" }, { 13, "][" }, { 9, "[]" }, { 5, "[]" }, { 49, "][" } }) do
        child.api.nvim_win_set_cursor(0, { case[1], 0 })
        expect.error(function()
            child.type_keys(case[2])
        end, "No section here")
        expect.equality(child.api.nvim_win_get_cursor(0), { case[1], 0 })
    end
end

T["[u in body text jumps to the title of the section around the cursor"] = function()
    expect.equality(jump(15, "[u", 2), { 13, 0 })
    expect.equality(jump(11, "[u"), { 9, 0 })
    expect.equality(jump(47, "[u"), { 45, 0 })
end

T["[u on a title or its metadata jumps to the parent's title"] = function()
    expect.equality(jump(13, "[u"), { 9, 0 })
    expect.equality(jump(9, "[u"), { 5, 0 })
    expect.equality(jump(45, "[u"), { 43, 0 })
end

T["[u with a count goes that many levels out"] = function()
    expect.equality(jump(41, "2[u"), { 35, 0 })
    expect.equality(jump(13, "2[u"), { 5, 0 })
end

T["[u in a top-level section or past the outermost level finds no target"] = function()
    -- the document title is not a section
    for _, case in ipairs({ { 5, "[u" }, { 34, "[u" }, { 41, "3[u" }, { 3, "[u" } }) do
        child.api.nvim_win_set_cursor(0, { case[1], 0 })
        expect.error(function()
            child.type_keys(case[2])
        end, "No section here")
        expect.equality(child.api.nvim_win_get_cursor(0), { case[1], 0 })
    end
end

T["]u jumps to the next sibling of the section [u reaches"] = function()
    -- on a title: the parent's next sibling
    expect.equality(jump(9, "]u"), { 26, 0 })
    expect.equality(jump(13, "]u"), { 17, 0 })
    -- in body text: the next sibling of the section around the cursor
    expect.equality(jump(11, "]u"), { 17, 0 })
    expect.equality(jump(37, "]u"), { 43, 0 })
end

T["]u with a count goes that many levels out, then to the next sibling"] = function()
    expect.equality(jump(13, "2]u"), { 26, 0 })
    expect.equality(jump(41, "2]u"), { 43, 0 })
end

T["]u finds no target without a parent or after the last sibling"] = function()
    -- 26: top-level title, 15: One A x is the last of its siblings,
    -- 45: Four is the last top-level section
    for _, case in ipairs({ { 26, "]u" }, { 15, "]u" }, { 45, "]u" }, { 13, "3]u" } }) do
        child.api.nvim_win_set_cursor(0, { case[1], 0 })
        expect.error(function()
            child.type_keys(case[2])
        end, "No section here")
        expect.equality(child.api.nvim_win_get_cursor(0), { case[1], 0 })
    end
end

T["a count repeats ]] [[ ][ []"] = function()
    expect.equality(jump(1, "3]]"), { 13, 0 })
    expect.equality(jump(49, "3[["), { 39, 0 })
    expect.equality(jump(5, "2]["), { 35, 0 })
    expect.equality(jump(43, "3[]"), { 5, 0 })
end

T["a count past the last target finds no target"] = function()
    for _, case in ipairs({ { 43, "3]]" }, { 9, "4[[" }, { 26, "3][" }, { 17, "2[]" } }) do
        child.api.nvim_win_set_cursor(0, { case[1], 0 })
        expect.error(function()
            child.type_keys(case[2])
        end, "No section here")
        expect.equality(child.api.nvim_win_get_cursor(0), { case[1], 0 })
    end
end

--- Return the visual selection as `{ mode, { start_line, start_col },
--- { cursor_line, cursor_col } }`.
local function selection()
    return child.lua_get([[{ vim.fn.mode(), { vim.fn.line("v"), vim.fn.col("v") - 1 },
        vim.api.nvim_win_get_cursor(0) }]])
end

T["visual mode"] = MiniTest.new_set()

T["visual mode"]["the motions extend the selection to the target title"] = function()
    jump(7, "v]]", 3)
    expect.equality(selection(), { "v", { 7, 3 }, { 9, 0 } })
    child.type_keys("<Esc>")
    jump(41, "V[[")
    expect.equality(selection(), { "V", { 41, 0 }, { 39, 0 } })
    child.type_keys("<Esc>")
    jump(11, "v][")
    expect.equality(selection(), { "v", { 11, 0 }, { 17, 0 } })
    child.type_keys("<Esc>")
    jump(19, "v[]")
    expect.equality(selection(), { "v", { 19, 0 }, { 9, 0 } })
    child.type_keys("<Esc>")
    jump(15, "v2[u")
    expect.equality(selection(), { "v", { 15, 0 }, { 9, 0 } })
    child.type_keys("<Esc>")
    jump(11, "v]u")
    expect.equality(selection(), { "v", { 11, 0 }, { 17, 0 } })
end

T["visual mode"]["repeated motions keep extending the selection"] = function()
    jump(1, "V]]]]")
    expect.equality(selection(), { "V", { 1, 0 }, { 9, 0 } })
end

T["visual mode"]["without a target the selection stays"] = function()
    jump(51, "v")
    expect.error(function()
        child.type_keys("]]")
    end, "No section here")
    expect.equality(selection(), { "v", { 51, 0 }, { 51, 0 } })
end

local function lines(first, last)
    return child.api.nvim_buf_get_lines(0, first - 1, last, false)
end

T["operator-pending mode"] = MiniTest.new_set()

T["operator-pending mode"]["d]] deletes up to the next section and keeps its anchor"] = function()
    child.api.nvim_win_set_cursor(0, { 26, 0 })
    child.type_keys("d]]")
    expect.equality(lines(25, 27), { "", "[[three-anchor]]", "[appendix]" })
    expect.equality(#lines(1, -1), 44)
end

T["operator-pending mode"]["y[[ yanks back to the start of the section above"] = function()
    child.api.nvim_win_set_cursor(0, { 37, 0 })
    child.type_keys("y[[")
    expect.equality(child.fn.getregtype('"'), "V")
    expect.equality(child.fn.getreg('"'), "[[three-anchor]]\n[appendix]\n== Three\n\n")
end

T["operator-pending mode"]["c][ changes up to the next sibling section"] = function()
    child.api.nvim_win_set_cursor(0, { 26, 0 })
    child.type_keys("c][", "Changed", "<Esc>")
    expect.equality(lines(25, 27), { "", "Changed", "[[three-anchor]]" })
end

T["operator-pending mode"]["d[u deletes back to the title of the section around"] = function()
    child.api.nvim_win_set_cursor(0, { 41, 0 })
    child.type_keys("d[u")
    expect.equality(lines(38, 40), { "", "Text three A.", "" })
end

T["operator-pending mode"]["without a target the operator is cancelled"] = function()
    child.fn.setreg('"', "kept")
    child.api.nvim_win_set_cursor(0, { 51, 0 })
    for _, keys in ipairs({ "y]]", "d][", "c]]" }) do
        expect.error(function()
            child.type_keys(keys)
        end, "No section here")
        expect.equality(child.fn.mode(), "n")
    end
    expect.equality(child.fn.getreg('"'), "kept")
    expect.equality(#lines(1, -1), 51)
end

T["operator-pending mode"]["dot resolves the motion again from the cursor"] = function()
    child.api.nvim_win_set_cursor(0, { 5, 0 })
    child.type_keys("d]]")
    expect.equality(lines(5, 5), { "=== One A" })
    child.type_keys(".")
    expect.equality(lines(5, 5), { "==== One A x" })
end

T["operator-pending mode"]["d]u deletes up to the next section at the parent's level"] = function()
    child.api.nvim_win_set_cursor(0, { 37, 0 })
    child.type_keys("d]u")
    expect.equality(lines(36, 37), { "", "== Four" })
end

T["operator-pending mode"]["d]] on the metadata above a title deletes forward"] = function()
    child.api.nvim_win_set_cursor(0, { 34, 0 })
    child.type_keys("d]]")
    expect.equality(lines(33, 35), { "[[three-anchor]]", "=== Three A", "" })
end

T["operator-pending mode"]["dot after d]] crosses the next section's anchor"] = function()
    child.api.nvim_win_set_cursor(0, { 26, 0 })
    child.type_keys("d]]")
    expect.equality(lines(26, 26), { "[[three-anchor]]" })
    child.type_keys(".")
    expect.equality(lines(26, 26), { "=== Three A" })
end

T["text after a discrete heading belongs to the section before it"] = function()
    expect.equality(jump(24, "[u"), { 17, 0 })
    expect.equality(jump(24, "[]"), { 9, 0 })
    child.api.nvim_win_set_cursor(0, { 24, 0 })
    expect.error(function()
        child.type_keys("][")
    end, "No section here")
    expect.equality(child.api.nvim_win_get_cursor(0), { 24, 0 })
end

T["a section's anchor, attributes and title count as its start"] = function()
    for _, line in ipairs({ 33, 34, 35 }) do
        expect.equality(jump(line, "]]"), { 39, 0 })
        expect.equality(jump(line, "[["), { 26, 0 })
    end
    -- body text below the title still goes back to it
    expect.equality(jump(37, "[["), { 35, 0 })
end

T["<C-o> returns to where ]] started"] = function()
    jump(7, "]]", 3)
    child.type_keys("<C-o>")
    expect.equality(child.api.nvim_win_get_cursor(0), { 7, 3 })
end

--- Restart the child with `config` as `vim.g.asciidoc` and open the fixture.
local function restart_with(config)
    child.restart({
        "--cmd",
        "lua vim.g.asciidoc = " .. config,
        "-u",
        vim.g.asciidoc_nvim_root .. "/tests/minimal_init.lua",
    })
    child.cmd("edit " .. fixture)
end

local default_keys = { "]]", "[[", "][", "[]", "[u", "]u" }

T["config"] = MiniTest.new_set()

T["config"]["motions.enable = false maps none of the keys"] = function()
    restart_with("{ motions = { enable = false } }")
    -- the ftplugin did run
    expect.equality(child.bo.commentstring, "// %s")
    for _, lhs in ipairs(default_keys) do
        for _, mode in ipairs({ "n", "x", "o" }) do
            expect.equality(child.fn.maparg(lhs, mode), "")
        end
    end
end

T["config"]["motions.keys remaps a single key"] = function()
    restart_with('{ motions = { keys = { parent = "gh" } } }')
    expect.equality(child.fn.maparg("[u", "n"), "")
    expect.equality(jump(11, "gh"), { 9, 0 })
    expect.equality(jump(9, "]]"), { 13, 0 })
end

T["config"]["a key set to false is not mapped, the others stay"] = function()
    restart_with("{ motions = { keys = { next = false } } }")
    for _, mode in ipairs({ "n", "x", "o" }) do
        expect.equality(child.fn.maparg("]]", mode), "")
    end
    expect.equality(jump(9, "[["), { 5, 0 })
end

T["motions are mapped only in AsciiDoc buffers"] = function()
    expect.no_equality(child.fn.maparg("]]", "n"), "")
    child.cmd("enew")
    expect.equality(child.fn.maparg("]]", "n"), "")
end

return T

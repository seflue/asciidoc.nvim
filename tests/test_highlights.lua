local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

T["highlights a block anchor's brackets, id and reftext"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/sections.adoc")
    local ranges = function(capture)
        return vim.tbl_filter(function(range)
            return range[1] == 15
        end, helpers.capture_ranges(child, "highlights", capture))
    end
    expect.equality(ranges("punctuation.delimiter"), { { 15, 0, 15, 2 }, { 15, 20, 15, 22 } })
    expect.equality(ranges("label"), { { 15, 2, 15, 8 } })
    expect.equality(ranges("markup.link.label"), { { 15, 9, 15, 20 } })
end

T["highlights only a complete attribute entry's name, not a `:to` line"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/attribute_entries.adoc")
    expect.equality(helpers.capture_ranges(child, "highlights", "property"), { { 7, 1, 7, 5 } })
end

T["highlights the attribute entry after a `:to` line in the header"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/attribute_header.adoc")
    expect.equality(helpers.capture_ranges(child, "highlights", "property"), { { 2, 1, 2, 4 } })
end

-- The block body is @markup.raw.block, but where the injected language
-- highlights a token, its colour is the one on screen.
T["shows the injected language's colour over a source block's body"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/source_block.adoc")
    -- a closed fold hides the block body from the screen
    child.cmd("setlocal nofoldenable")
    local attrs = child.lua_get([[(function()
        vim.o.termguicolors = true
        vim.api.nvim_set_hl(0, "@markup.raw.block", { fg = "#ff0000" })
        vim.api.nvim_set_hl(0, "@keyword.lua", { fg = "#00ff00" })
        -- Reference cell: the `t` of "text." drawn in the keyword colour alone.
        vim.api.nvim_buf_set_extmark(0, vim.api.nvim_create_namespace("test"), 2, 6, {
            end_col = 7,
            hl_group = "@keyword.lua",
            priority = 200,
        })
        vim.treesitter.get_parser(0):parse(true)
        vim.cmd.redraw({ bang = true })
        local function attr(lnum, col)
            local pos = vim.fn.screenpos(0, lnum, col)
            return vim.fn.screenattr(pos.row, pos.col)
        end
        return { plain = attr(3, 1), lua = attr(3, 7), body = attr(7, 6), keyword = attr(7, 1) }
    end)()]])
    -- The space after `local` carries only the block capture.
    expect.no_equality(attrs.body, attrs.plain)
    expect.equality(attrs.keyword, attrs.lua)
end

-- Open `lines` as an AsciiDoc scratch buffer with injections parsed.
local function open_text(lines)
    child.cmd("enew")
    child.bo.filetype = "asciidoc"
    child.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    child.lua([[vim.treesitter.get_parser(0):parse(true)]])
end

-- Capture names at (row, col), 0-based, in priority order: the last wins.
local function captures_at(row, col, lang)
    return child.lua_get(
        [[(function(row, col, lang)
        local names = {}
        for _, c in ipairs(vim.treesitter.get_captures_at_pos(0, row, col)) do
            if c.lang == lang and c.capture:sub(1, 1) ~= "_" then
                names[#names + 1] = c.capture
            end
        end
        return names
    end)(...)]],
        { row, col, lang }
    )
end

-- Whether the block grammar gives `capture` to the first column of `row`.
local function has_capture_at(row, capture)
    return vim.tbl_contains(captures_at(row, 0, "asciidoc"), capture)
end

-- Rows on which `capture` starts in the block grammar.
local function rows_of(capture)
    return vim.tbl_map(function(range)
        return range[1]
    end, helpers.capture_ranges(child, "highlights", capture))
end

T["limits the document title heading to the title line"] = function()
    open_text({ "= Title", "Ada Lovelace <ada@example.org>", "v1.0, 2026-01-01: Draft" })
    expect.equality(helpers.capture_ranges(child, "highlights", "markup.heading.1"), {
        { 0, 0, 0, 1 },
        { 0, 2, 1, 0 },
    })
end

T["highlights a listing without a style as raw"] = function()
    open_text({ "----", "*x*", "----" })
    expect.equality(rows_of("markup.raw.block"), { 1 })
end

T["highlights a listing with only named attributes as raw"] = function()
    open_text({ "[subs=+quotes]", "----", "*x*", "----" })
    expect.equality(rows_of("markup.raw.block"), { 2 })
end

T["highlights a listing with only shorthands as raw"] = function()
    open_text({ "[#id.role]", "----", "*x*", "----" })
    expect.equality(rows_of("markup.raw.block"), { 2 })
end

T["highlights a titled listing without a style as raw"] = function()
    open_text({ ".Title", "----", "*x*", "----" })
    expect.equality(rows_of("markup.raw.block"), { 2 })
end

T["highlights a listing under a block anchor as raw"] = function()
    open_text({ "[[lid]]", "----", "*w*", "----" })
    expect.equality(rows_of("markup.raw.block"), { 2 })
end

T["highlights a listing in a list continuation as raw"] = function()
    open_text({ "* item", "+", "----", "*v*", "----" })
    expect.equality(rows_of("markup.raw.block"), { 3 })
end

T["keeps a diagram listing with a shorthand from being raw"] = function()
    open_text({ "[plantuml#arch]", "----", "b", "----" })
    expect.equality(rows_of("markup.raw.block"), {})
end

T["keeps a diagram listing with a title after the style from being raw"] = function()
    open_text({ "[plantuml]", ".Title", "----", "b", "----" })
    expect.equality(rows_of("markup.raw.block"), {})
end

T["highlights the source style as a type, not an attribute"] = function()
    open_text({ "[source,rust]", "----", "fn x() {}", "----" })
    local names = captures_at(0, 1, "asciidoc")
    expect.equality(names[#names], "type")
end

T["highlights the body of an admonition block"] = function()
    open_text({ "[NOTE]", "====", "text", "====" })
    for _, row in ipairs({ 1, 2, 3 }) do
        expect.equality(has_capture_at(row, "comment.note"), true)
    end
end

T["highlights an admonition block whose style has a shorthand"] = function()
    open_text({ "[NOTE.role]", "====", "text", "====" })
    for _, row in ipairs({ 1, 2, 3 }) do
        expect.equality(has_capture_at(row, "comment.note"), true)
    end
end

T["highlights every paragraph of an admonition block"] = function()
    open_text({ "[NOTE]", "====", "a1", "a2", "", "b1", "b2", "====" })
    expect.equality(has_capture_at(2, "comment.note"), true)
    expect.equality(has_capture_at(5, "comment.note"), true)
end

T["highlights the body of a literal block as raw"] = function()
    open_text({ "....", "*x*", "...." })
    expect.equality(rows_of("markup.raw.block"), { 1 })
end

T["highlights the angle brackets of an autolink, not a comparison"] = function()
    open_text({ "<https://example.org> and 1 < 2 > 0" })
    for _, col in ipairs({ 0, 20 }) do
        local names = captures_at(0, col, "asciidoc_inline")
        expect.equality(names[#names], "punctuation.bracket")
    end
    for _, col in ipairs({ 26, 30 }) do
        expect.equality(vim.tbl_contains(captures_at(0, col, "asciidoc_inline"), "punctuation.bracket"), false)
    end
end

T["highlights a macro name but not a prose word that reads like one"] = function()
    open_text({ "link:https://example.org[x] and a link here" })
    expect.equality(vim.tbl_contains(captures_at(0, 0, "asciidoc_inline"), "keyword"), true)
    expect.equality(vim.tbl_contains(captures_at(0, 36, "asciidoc_inline"), "keyword"), false)
end

T["highlights the body of a CAUTION, WARNING or IMPORTANT block"] = function()
    for _, style in ipairs({ "CAUTION", "WARNING", "IMPORTANT" }) do
        open_text({ "[" .. style .. "]", "====", "text", "====" })
        local capture = style == "IMPORTANT" and "comment.error" or "comment.warning"
        for _, row in ipairs({ 1, 2, 3 }) do
            expect.equality({ style, has_capture_at(row, capture) }, { style, true })
        end
    end
end

T["highlights an admonition style over a paragraph"] = function()
    open_text({ "[NOTE]", "text" })
    expect.equality(has_capture_at(0, "comment.note"), true)
    expect.equality(has_capture_at(1, "comment.note"), false)
end

T["highlights a paragraph after a list, a listing or a table in an admonition block"] = function()
    open_text({
        "[NOTE]",
        "====",
        "One",
        "",
        "* item",
        "",
        "Two",
        "",
        "----",
        "code",
        "----",
        "",
        "|===",
        "| a",
        "|===",
        "",
        "Three",
        "====",
    })
    for _, row in ipairs({ 2, 6, 16 }) do
        expect.equality({ row, has_capture_at(row, "comment.note") }, { row, true })
    end
    expect.equality(has_capture_at(4, "comment.note"), false)
end

T["highlights every paragraph of a WARNING block with a shorthand style"] = function()
    open_text({ "[WARNING#warn-id.role]", "====", "One", "", "* item", "", "Two", "====" })
    for _, row in ipairs({ 2, 6 }) do
        expect.equality({ row, has_capture_at(row, "comment.warning") }, { row, true })
    end
end

T["leaves a paragraph of a nested block in an admonition body alone"] = function()
    open_text({ "[WARNING]", "====", "One", "", "****", "side", "****", "", "Two", "====" })
    expect.equality(has_capture_at(2, "comment.warning"), true)
    expect.equality(has_capture_at(8, "comment.warning"), true)
    expect.equality(has_capture_at(5, "comment.warning"), false)
end

-- Asciidoctor makes an admonition only from a paragraph, an example block
-- or an open block.
T["leaves an admonition style over another block uncoloured"] = function()
    local blocks = {
        { "----", "x", "----" },
        { "****", "x", "****" },
        { "....", "x", "...." },
        { "|===", "| x", "|===" },
        { "* x" },
    }
    for _, block in ipairs(blocks) do
        for _, style in ipairs({ "NOTE", "WARNING", "IMPORTANT" }) do
            local capture = style == "NOTE" and "comment.note" or (style == "WARNING" and "comment.warning" or "comment.error")
            open_text(vim.list_extend({ "[" .. style .. "]" }, block))
            -- The style line, the markers and the body stay plain.
            for row = 0, #block do
                expect.equality({ block[1], style, row, has_capture_at(row, capture) }, { block[1], style, row, false })
            end
        end
    end
end

T["highlights an admonition style over an example block or an open block"] = function()
    for _, delimiter in ipairs({ "====", "--" }) do
        open_text({ "[TIP]", delimiter, "x", delimiter })
        expect.equality({ delimiter, has_capture_at(0, "comment.note") }, { delimiter, true })
    end
end

T["highlights the markers and every direct paragraph of an open block"] = function()
    open_text({ "[NOTE]", "--", "a", "", "* item", "", "b", "", "****", "side", "****", "--" })
    for _, row in ipairs({ 1, 2, 6, 11 }) do
        expect.equality({ row, has_capture_at(row, "comment.note") }, { row, true })
    end
    expect.equality(has_capture_at(9, "comment.note"), false)
end

T["leaves a list continuation paragraph in an admonition body alone"] = function()
    open_text({ "[NOTE]", "====", "One", "", "* item", "+", "para", "====" })
    expect.equality(has_capture_at(2, "comment.note"), true)
    expect.equality(has_capture_at(6, "comment.note"), false)
end

T["leaves a title line in an admonition body plain"] = function()
    open_text({ "[NOTE]", "====", ".Title", "text", "====" })
    expect.equality(has_capture_at(2, "comment.note"), false)
    expect.equality(has_capture_at(3, "comment.note"), true)
end

T["highlights an admonition style with a shorthand over a paragraph"] = function()
    open_text({ "[NOTE.role]", "text" })
    expect.equality(has_capture_at(0, "comment.note"), true)
end

T["highlights the comma of a revision line without a remark"] = function()
    open_text({ "= Title", "Ada Lovelace <ada@example.org>", "v1.0, 2026-01-01" })
    local names = captures_at(2, 4, "asciidoc")
    expect.equality(names[#names], "punctuation.delimiter")
end

-- A diagram style on a literal block is raw: only listings get the diagram
-- injection, so the raw body is the only highlight there.
T["highlights the body of a diagram literal block as raw"] = function()
    open_text({ "[ditaa]", "....", "b", "...." })
    expect.equality(rows_of("markup.raw.block"), { 2 })
end

T["keeps a diagram listing with a later positional from being raw"] = function()
    open_text({ "[plantuml,x]", "----", "b", "----" })
    expect.equality(rows_of("markup.raw.block"), {})
end

T["highlights the names of footnote, stem and passthrough macros"] = function()
    for _, text in ipairs({ "footnote:[x]", "stem:[x]", "pass:[x]" }) do
        open_text({ text })
        expect.equality({ text, vim.tbl_contains(captures_at(0, 0, "asciidoc_inline"), "keyword") }, { text, true })
    end
end

return T

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

return T

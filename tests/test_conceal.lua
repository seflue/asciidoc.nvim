local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = child.setup,
        post_once = child.stop,
    },
})

local fixture = vim.g.asciidoc_nvim_root .. "/tests/fixtures/conceal.adoc"

local SOURCE = {
    "*fett* und **fett**",
    "_kursiv_ und __kursiv__",
    "`mono` und ``mono``",
    "#mark# und ##mark##",
    "[.role]#x# und *_beides_*",
    "^hoch^ ~tief~ +pass+",
}

--- Open the fixture with `config` as `vim.g.asciidoc`, set `conceallevel`,
--- put the cursor on 1-based `line` and return the first six screen rows as
--- they are drawn.
local function screen(config, conceallevel, line)
    return child.lua(
        [[
        local config, fixture, conceallevel, line = ...
        vim.g.asciidoc = config
        package.loaded["asciidoc.config"] = nil
        vim.cmd.edit(fixture)
        vim.wo.conceallevel = conceallevel
        vim.wo.spell = false
        vim.api.nvim_win_set_cursor(0, { line, 0 })
        vim.cmd.redraw()
        local rows = {}
        for row = 1, 6 do
            local text = {}
            for col = 1, vim.o.columns do
                text[#text + 1] = vim.fn.screenstring(row, col)
            end
            rows[row] = (table.concat(text):gsub("%s+$", ""))
        end
        return rows
    ]],
        { config or vim.empty_dict(), fixture, conceallevel, line }
    )
end

T["hides the delimiters of strong, italic, monospace and highlighted text"] = function()
    expect.equality(screen(nil, 2, 7), {
        "fett und fett",
        "kursiv und kursiv",
        "mono und mono",
        "mark und mark",
        "[.role]x und beides",
        "^hoch^ ~tief~ +pass+",
    })
end

T["shows the delimiters on the cursor line"] = function()
    local rows = screen(nil, 2, 1)
    expect.equality(rows[1], SOURCE[1])
    expect.equality(rows[2], "kursiv und kursiv")
end

T["hides nothing at conceallevel 0"] = function()
    expect.equality(screen(nil, 0, 7), SOURCE)
end

T["hides nothing when disabled"] = function()
    expect.equality(screen({ conceal = { enable = false } }, 2, 7), SOURCE)
end

return T

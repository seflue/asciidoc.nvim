local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.setup()
            -- With the fold expression's async parse running from `:edit`,
            -- `]s` at times misses the inline nospell regions. Parse
            -- synchronously (a private flag of Neovim's tree-sitter runtime)
            -- so the walk sees the full tree.
            child.lua("vim.g._ts_force_sync_parsing = true")
        end,
        post_once = child.stop,
    },
})

--- Walk the buffer with `]s` and return every word Neovim treats as misspelled.
local function misspelled_words()
    return child.lua_get([[(function()
        vim.treesitter.get_parser(0):parse(true)
        vim.o.spelllang = "en"
        vim.o.wrapscan = false
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        local words, previous = {}, nil
        for _ = 1, 200 do
            pcall(vim.cmd, "silent normal! ]s")
            local pos = vim.api.nvim_win_get_cursor(0)
            local key = pos[1] .. ":" .. pos[2]
            if key == previous then
                break
            end
            previous = key
            words[#words + 1] = vim.fn.spellbadword()[1]
        end
        return words
    end)()]])
end

T["starts treesitter highlighting for asciidoc buffers"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/spell.adoc")
    expect.equality(child.lua_get("vim.treesitter.highlighter.active[vim.api.nvim_get_current_buf()] ~= nil"), true)
end

T["spellchecks prose and skips AsciiDoc syntax"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/spell.adoc")
    expect.equality(misspelled_words(), {
        "Titel",
        "tyypo",
        "Headding",
        "tyypo",
        "paragrph",
        "targett",
        "lable",
        "linktextt",
        "alttextt",
        "hilited",
        "boldd",
        "iteem",
        "titell",
        "Zellee",
        "zellentextt",
        "commment",
        "admonitoin",
    })
end

T["skips the passthrough macro but spellchecks prose next to it"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/spell.adoc")
    child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "A pass:[wierd_tokn <br>] and a tyypo.",
        "Also +++<br>wierdd+++ and ++wierdd++ here.",
    })]])
    expect.equality(misspelled_words(), { "tyypo" })
end

T["spellchecks paragraphs and list items inside a quote block"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/spell.adoc")
    child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "[quote,Autor]",
        "____",
        "A tyypo and *boldd* text",
        "on two lines.",
        "",
        "* iteem here",
        "____",
    })]])
    expect.equality(misspelled_words(), { "tyypo", "boldd", "iteem" })
end

T["skips pass macros with substitutions"] = function()
    child.cmd("edit " .. vim.g.asciidoc_nvim_root .. "/tests/fixtures/spell.adoc")
    child.lua([[vim.api.nvim_buf_set_lines(0, 0, -1, false, {
        "See pass:q[<u>Undrline *thiss*</u>] and pass:quotes[*boldd*] and a tyypo.",
    })]])
    expect.equality(misspelled_words(), { "tyypo" })
end

return T

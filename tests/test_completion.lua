-- Completion after `xref:` with Neovim's built-in client (omnifunc and
-- vim.lsp.completion). The buffer's 'iskeyword' contains `:` but not `/`, so
-- the client's own guess of the typed word would be wrong; these tests pin
-- that the server's edits replace the whole typed target.
local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

-- Line 3 of the fixture is the line under test; `chapters/` holds
-- 01_intro.adoc and 02_more.adoc, and the document has a `== Goals` section.
local fixture = "tests/fixtures/xref_paths/index.adoc"

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.setup()
            helpers.edit_with_lsp(child, fixture)
        end,
        post_once = child.stop,
    },
})

local function set_line(text)
    child.api.nvim_buf_set_lines(0, 2, 3, false, { text })
    child.api.nvim_win_set_cursor(0, { 3, 0 })
end

-- Labels shown in the completion menu, once it has items or after 5 s.
local function menu_labels()
    local labels = {}
    for _ = 1, 100 do
        local items = child.fn.complete_info({ "items" }).items
        if #items > 0 then
            for _, item in ipairs(items) do
                labels[#labels + 1] = item.abbr
            end
            table.sort(labels)
            return labels
        end
        vim.uv.sleep(50)
    end
    return labels
end

local function complete_with(mode)
    if mode == "omnifunc" then
        child.bo.omnifunc = "v:lua.vim.lsp.omnifunc"
        child.type_keys("A", "<C-x><C-o>")
    else
        child.lua([[
            local client = vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1]
            vim.lsp.completion.enable(true, client.id, 0, { autotrigger = false })
        ]])
        child.type_keys("A")
        child.lua("vim.lsp.completion.get()")
    end
end

local cases = {
    {
        typed = "See xref:chapters/",
        first = "01_intro.adoc",
        accepted = "See xref:chapters/01_intro.adoc[label]",
    },
    {
        typed = "See xref:chapters/0",
        first = "01_intro.adoc",
        accepted = "See xref:chapters/01_intro.adoc[label]",
    },
    { typed = "See xref:chap", first = "chapters/", accepted = "See xref:chapters/" },
    { typed = "See xref:_go", first = "_goals", accepted = "See xref:_goals[label]" },
}

for _, mode in ipairs({ "omnifunc", "vim.lsp.completion" }) do
    T[mode] = MiniTest.new_set()
    for _, case in ipairs(cases) do
        T[mode][case.typed] = function()
            set_line(case.typed)
            complete_with(mode)
            expect.equality(menu_labels()[1], case.first)
            child.type_keys("<C-y>")
            expect.equality(child.api.nvim_get_current_line(), case.accepted)
        end
    end
end

T["typing / after a folder lists its files"] = function()
    set_line("See xref:chapters")
    child.lua([[
        local client = vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1]
        vim.lsp.completion.enable(true, client.id, 0, { autotrigger = true })
    ]])
    child.type_keys("A", "/")
    expect.equality(menu_labels(), { "01_intro.adoc", "02_more.adoc" })
end

return T

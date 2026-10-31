local helpers = require("helpers")
local expect = MiniTest.expect

local child = helpers.new_child()

local TITLE = "One sentence per line"

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            child.setup()
            helpers.edit_with_lsp(child, "tests/fixtures/ventilate.adoc")
        end,
        post_once = child.stop,
    },
})

-- Put the cursor on the first line matching `pattern` and return the titles
-- of the code actions the server offers there.
local function action_titles_at(pattern)
    child.fn.search(pattern)
    return child.lua_get([[(function()
        local params = vim.lsp.util.make_range_params(0, "utf-16")
        params.context = { diagnostics = {} }
        local responses = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, 5000) or {}
        local titles = {}
        for _, response in pairs(responses) do
            for _, action in ipairs(response.result or {}) do
                table.insert(titles, action.title)
            end
        end
        return titles
    end)()]])
end

-- Apply the "One sentence per line" action at the first line matching `pattern`.
local function ventilate_at(pattern)
    child.fn.search(pattern)
    child.lua([[local title = ...
        vim.lsp.buf.code_action({
            apply = true,
            filter = function(action) return action.title == title end,
        })]], { TITLE })
    child.lua("vim.wait(5000, function() return vim.bo.modified end, 20)")
end

local function lines()
    return child.api.nvim_buf_get_lines(0, 0, -1, true)
end

T["rewrites a paragraph with emoji and umlauts"] = function()
    ventilate_at("^Party")
    expect.equality(lines(), {
        "= Ventilate Fixture",
        "",
        "Party 🎉 time.",
        "Größe ändern.",
        "Done.",
        "",
        "This sentence was wrapped",
        "at seventy-two columns. And a second one",
        "follows here.",
        "",
        "Already one.",
        "Per line.",
        "",
        "* Item one. Two.",
        "continued here. More.",
    })
end

T["rewrites the whole paragraph from its last line"] = function()
    ventilate_at("^follows here")
    expect.equality(lines(), {
        "= Ventilate Fixture",
        "",
        "Party 🎉 time. Größe ändern. Done.",
        "",
        "This sentence was wrapped at seventy-two columns.",
        "And a second one follows here.",
        "",
        "Already one.",
        "Per line.",
        "",
        "* Item one. Two.",
        "continued here. More.",
    })
end

T["is not offered on an already ventilated paragraph"] = function()
    expect.equality(vim.tbl_contains(action_titles_at("^Per line"), TITLE), false)
end

T["is not offered on a title"] = function()
    expect.equality(vim.tbl_contains(action_titles_at("^= Ventilate"), TITLE), false)
end

T["is not offered on a list item"] = function()
    expect.equality(vim.tbl_contains(action_titles_at([[^\* Item]]), TITLE), false)
end

T["is not offered on a list item continuation"] = function()
    expect.equality(vim.tbl_contains(action_titles_at("^continued here"), TITLE), false)
end

T["is offered on a paragraph that would change"] = function()
    expect.equality(vim.tbl_contains(action_titles_at("^This sentence"), TITLE), true)
end

-- True if any buffer line starts with `prefix`.
local function some_line_starts_with(prefix)
    for _, line in ipairs(lines()) do
        if vim.startswith(line, prefix) then
            return true
        end
    end
    return false
end

T["keeps a comment marker off the line start"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/ventilate_guards.adoc")
    ventilate_at("^A1")
    expect.equality(lines(), {
        "= Ventilate Guards",
        "",
        "A1 one.",
        "B1 two. // c1 text.",
        "D1 four.",
        "",
        "A3 one. B3 two. NOTE: c3 text. D3 four.",
    })
    expect.equality(some_line_starts_with("//"), false)
end

T["keeps an admonition label off the line start"] = function()
    helpers.edit_with_lsp(child, "tests/fixtures/ventilate_guards.adoc")
    ventilate_at("^A3")
    expect.equality(lines(), {
        "= Ventilate Guards",
        "",
        "A1 one. B1 two. // c1 text. D1 four.",
        "",
        "A3 one.",
        "B3 two. NOTE: c3 text.",
        "D3 four.",
    })
    expect.equality(some_line_starts_with("NOTE: "), false)
end

T["leaves the file unchanged on save"] = function()
    local original = lines()
    -- Save a copy outside the repository, so a format-on-save could not
    -- touch the fixture.
    local path = child.lua_get([[(function()
        local path = vim.fn.tempname() .. ".adoc"
        vim.cmd.saveas(vim.fn.fnameescape(path))
        vim.wait(10000, function()
            local client = vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1]
            return client ~= nil and client.initialized
        end, 20)
        return path
    end)()]])
    child.cmd("write")
    expect.equality(lines(), original)
    expect.equality(child.fn.readfile(path), original)
    expect.equality(child.bo.modified, false)
end

T["offers no formatting capability"] = function()
    local capabilities = child.lua_get([[(function()
        local caps = vim.lsp.get_clients({ bufnr = 0, name = "asciidoc" })[1].server_capabilities
        return {
            document = caps.documentFormattingProvider or vim.NIL,
            range = caps.documentRangeFormattingProvider or vim.NIL,
        }
    end)()]])
    expect.equality(capabilities, { document = vim.NIL, range = vim.NIL })
end

T["is undone in one step"] = function()
    local original = lines()
    ventilate_at("^This sentence")
    expect.no_equality(lines(), original)
    child.cmd("undo")
    expect.equality(lines(), original)
    expect.equality(child.bo.modified, false)
end

return T

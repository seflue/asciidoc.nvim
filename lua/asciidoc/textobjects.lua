-- Section text objects `iS` / `aS` built on the bundled textobjects query,
-- so they select exactly what `@section.inner` / `@section.outer` capture.

local M = {}

--- Return `{ start_row, end_row }` (0-based, end exclusive) for a capture
--- spanning `first` to `last`.
local function line_span(first, last)
    local srow = first:range()
    local _, _, erow, ecol = last:range()
    return { srow, ecol == 0 and erow or erow + 1 }
end

--- Sections containing 0-based `row`, innermost first. Each entry has
--- `outer` and, unless the section is only a title, `inner`.
local function sections_at(bufnr, row)
    local parser = vim.treesitter.get_parser(bufnr, "asciidoc", { error = false })
    local query = vim.treesitter.query.get("asciidoc", "textobjects")
    if not parser or not query then
        return {}
    end
    local by_id = {}
    for _, match in query:iter_matches(parser:parse()[1]:root(), bufnr) do
        for id, nodes in pairs(match) do
            local capture = query.captures[id]
            if capture == "section.outer" or capture == "section.inner" then
                local section = capture == "section.outer" and nodes[1] or nodes[1]:parent()
                local entry = by_id[section:id()] or { outer = line_span(section, section) }
                by_id[section:id()] = entry
                if capture == "section.inner" then
                    entry.inner = line_span(nodes[1], nodes[#nodes])
                end
            end
        end
    end
    local found = {}
    for _, entry in pairs(by_id) do
        if row >= entry.outer[1] and row < entry.outer[2] then
            found[#found + 1] = entry
        end
    end
    table.sort(found, function(a, b)
        return a.outer[1] > b.outer[1]
    end)
    return found
end

--- `{ first, last }` (1-based lines) of the `"inner"` or `"outer"` range of
--- the `count`-th section around `line`, innermost first, or nil.
local function span_at(kind, line, count)
    local section = sections_at(0, line - 1)[count]
    local span = section and section[kind]
    return span and { span[1] + 1, span[2] }
end

local function select_lines(span)
    vim.api.nvim_win_set_cursor(0, { span[1], 0 })
    vim.cmd("normal! V")
    vim.api.nvim_win_set_cursor(0, { span[2], 0 })
end

--- Keys that select the `"inner"` or `"outer"` range of the innermost
--- section around the cursor, linewise; with a count, of the section that
--- many levels out. In visual mode the top of the selection stands in for
--- the cursor, so repeating the object keeps the section. Without such a
--- range the keys cancel a pending operator and keep a visual selection.
function M.keys(kind)
    local visual = vim.fn.mode(true):find("^[vV\22]") ~= nil
    local line = visual and math.min(vim.fn.line("v"), vim.fn.line(".")) or vim.fn.line(".")
    local span = span_at(kind, line, vim.v.count1)
    if not span then
        return visual and "" or "<Esc>"
    end
    if visual then
        return ("<Esc><Cmd>lua require('asciidoc.textobjects').select_lines(%d, %d)<CR>"):format(span[1], span[2])
    end
    -- Resolved again when the operator runs, so `.` acts on the section
    -- under the cursor at that time.
    return ("<Cmd>lua require('asciidoc.textobjects').select(%q)<CR>"):format(kind)
end

--- Select the range for a pending operator from the cursor and count, or
--- cancel the operator (reached on `.` away from any section).
function M.select(kind)
    local span = span_at(kind, vim.fn.line("."), vim.v.count1)
    if span then
        select_lines(span)
    else
        -- An error from `<Cmd>` makes Neovim drop the pending operator.
        vim.api.nvim_echo({ { "No section here" } }, true, { err = true })
    end
end

--- Select lines `first` to `last` (1-based) linewise.
function M.select_lines(first, last)
    select_lines({ first, last })
end

--- Map `iS` / `aS` in visual and operator-pending mode for `bufnr`.
function M.attach(bufnr)
    vim.keymap.set({ "x", "o" }, "iS", function()
        return M.keys("inner")
    end, { buffer = bufnr, expr = true, desc = "Inside section" })
    vim.keymap.set({ "x", "o" }, "aS", function()
        return M.keys("outer")
    end, { buffer = bufnr, expr = true, desc = "Around section" })
end

return M

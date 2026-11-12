-- Conceal the delimiters of strong, italic, monospace and highlighted text.
--
-- The grammar exposes no node for an opening delimiter (the external scanner
-- emits it as a hidden token), so a query cannot capture it for @conceal.
-- Instead the delimiters are cut from each span's own range and drawn as
-- ephemeral extmarks while the window redraws, for the visible rows only.
-- Whether they are hidden is up to `conceallevel`, and whether the cursor
-- line shows them is up to `concealcursor`.

local M = {}

local ns = vim.api.nvim_create_namespace("asciidoc.conceal")

--- Spans whose delimiters are concealed. Superscript, subscript and
--- passthrough keep theirs: without them the text reads as plain text.
local SPANS = { "emphasis", "italic", "monospace", "highlight" }

local query

--- Delimiter ranges per row of the window's buffer, rebuilt on each redraw.
local marks = {}

--- Width of the delimiter a span with source `text` opens and closes with:
--- two for an unconstrained span such as `**x**`, one otherwise.
local function delimiter_width(text)
    local ch = text:sub(1, 1)
    if #text >= 4 and text:sub(2, 2) == ch and text:sub(-2, -2) == ch then
        return 2
    end
    return 1
end

local function add(row, scol, ecol)
    marks[row] = marks[row] or {}
    table.insert(marks[row], { scol, ecol })
end

--- Collect the delimiter ranges of every span between rows `top` and `bot`.
local function collect(buf, top, bot)
    marks = {}
    local ok, parser = pcall(vim.treesitter.get_parser, buf, "asciidoc")
    if not ok or not parser then
        return
    end
    parser:parse({ top, bot })
    parser:for_each_tree(function(tree, ltree)
        if ltree:lang() ~= "asciidoc_inline" then
            return
        end
        for _, node in query:iter_captures(tree:root(), buf, top, bot) do
            local srow, scol, erow, ecol = node:range()
            local width = delimiter_width(vim.treesitter.get_node_text(node, buf))
            add(srow, scol, scol + width)
            add(erow, ecol - width, ecol)
        end
    end)
end

local function on_win(_, _, buf, top, bot)
    if not vim.b[buf].asciidoc_conceal then
        return false
    end
    collect(buf, top, bot)
end

local function on_line(_, _, buf, row)
    for _, range in ipairs(marks[row] or {}) do
        vim.api.nvim_buf_set_extmark(buf, ns, row, range[1], {
            end_col = range[2],
            conceal = "",
            ephemeral = true,
        })
    end
end

--- Conceal the delimiters in `buf` from now on.
function M.attach(buf)
    if not query then
        local ok, parsed = pcall(vim.treesitter.query.parse, "asciidoc_inline", "[(" .. table.concat(SPANS, ") (") .. ")] @span")
        if not ok then
            return
        end
        query = parsed
        vim.api.nvim_set_decoration_provider(ns, { on_win = on_win, on_line = on_line })
    end
    vim.b[buf].asciidoc_conceal = true
end

return M

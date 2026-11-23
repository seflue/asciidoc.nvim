-- :AsciidocPreview: open the live preview from asciidoc-lsp in the browser
-- and, from then on, tell the server where the cursor is so the page
-- follows it (`asciidoc/cursorMoved`). Scrolling the page scrolls the
-- window back (`asciidoc/revealLine`), with the cursor when the page asks
-- for it (a chapter change, its start or end); a double-click in the page arrives
-- as `window/showDocument`, which Neovim's own handler opens.
--
-- Against the two sides pushing each other back and forth, a revealLine
-- does nothing when the line is already at the top of the window, and no
-- cursor move after it is reported until the user types a key or clicks:
-- the moves it forces, also those an animated scroll makes step by step,
-- come without one.

local M = {}

local THROTTLE_MS = 100
-- Lines a revealLine may differ from the window's top line and still
-- count as there: the page rounds its line.
local TOLERANCE = 1

-- Ids of the clients whose preview is open; the server ignores
-- cursorMoved without one, so nothing is sent before.
local open_clients = {}
local timer = nil
local group = nil
-- The buffer a revealLine moved last, until the user types a key or
-- clicks: its cursor moves till then are the reveal's echo.
local revealed_buf = nil

--- The asciidoc client attached to `bufnr` if its preview is open.
local function following_client(bufnr)
    if vim.bo[bufnr].filetype ~= "asciidoc" then
        return nil
    end
    for _, client in ipairs(vim.lsp.get_clients({ bufnr = bufnr, name = "asciidoc" })) do
        if open_clients[client.id] and not client:is_stopped() then
            return client
        end
    end
    return nil
end

--- Send the cursor line of the current buffer to its client, if it follows.
local function send_cursor()
    local bufnr = vim.api.nvim_get_current_buf()
    local client = following_client(bufnr)
    -- A send still pending from before a revealLine would report the cursor
    -- it forced.
    if not client or revealed_buf == bufnr then
        return
    end
    client:notify("asciidoc/cursorMoved", {
        uri = vim.uri_from_bufnr(bufnr),
        line = vim.api.nvim_win_get_cursor(0)[1] - 1,
    })
end

-- Trailing throttle: CursorMoved fires per keystroke. A running timer is
-- left alone, so continuous movement still sends once per window; the
-- position is read when the timer fires, so the last one wins. The timer
-- callback runs in a fast event context, so the work is deferred to the
-- main loop.
local function schedule_send()
    if not timer then
        timer = vim.uv.new_timer()
    end
    if timer:is_active() then
        return
    end
    timer:start(THROTTLE_MS, 0, vim.schedule_wrap(send_cursor))
end

--- The last row that fits in the window below `line` at its top, keeping
--- `scrolloff` screen lines free; counted in screen lines, as wrapped rows
--- take several.
local function last_row_in_view(line, scrolloff)
    local room = vim.api.nvim_win_get_height(0) - scrolloff
    local count = vim.api.nvim_buf_line_count(0)
    local used = 0
    local row = line
    while row <= count do
        used = used + vim.api.nvim_win_text_height(0, { start_row = row - 1, end_row = row - 1 }).all
        if used > room then
            break
        end
        row = row + 1
    end
    return math.max(line, row - 1)
end

--- Handler of `asciidoc/revealLine` ({ uri, line }, line 0-based): the
--- reader scrolled the page, show the line at the top of the window. Only
--- for the current buffer, and only while its preview is open.
function M.on_reveal_line(err, params)
    if err or type(params) ~= "table" or type(params.line) ~= "number" then
        return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    if params.uri ~= vim.uri_from_bufnr(bufnr) or not following_client(bufnr) then
        return
    end
    local line = math.min(params.line + 1, vim.api.nvim_buf_line_count(bufnr))
    local before = vim.api.nvim_win_get_cursor(0)
    if params.cursor == true then
        -- A chapter change, the start or the end of the page: the cursor
        -- goes to the line; the view moves only if it is out of sight.
        if line >= vim.fn.line("w0") and line <= vim.fn.line("w$") then
            vim.api.nvim_win_set_cursor(0, { line, 0 })
        else
            vim.fn.winrestview({ topline = line, lnum = line, col = 0 })
        end
        revealed_buf = bufnr
        return
    end
    if math.abs(vim.fn.line("w0") - line) <= TOLERANCE then
        return
    end
    -- Vim pulls the view back to a cursor outside it, so the cursor moves
    -- first, as little as needed to stay inside the new view.
    local scrolloff = math.min(vim.wo.scrolloff, math.floor((vim.api.nvim_win_get_height(0) - 1) / 2))
    local last = last_row_in_view(line, scrolloff)
    local first = math.min(line == 1 and 1 or line + scrolloff, last)
    local row = math.min(math.max(before[1], first), last)
    vim.fn.winrestview({ topline = line, lnum = row, col = row == before[1] and before[2] or 0 })
    revealed_buf = bufnr
end

local function ensure_autocmds()
    if group then
        return
    end
    vim.lsp.handlers["asciidoc/revealLine"] = M.on_reveal_line
    -- A typed key or a click is the user's; what moves the cursor after it
    -- is reported again. Keys from mappings and animations carry no typed form.
    vim.on_key(function(_, typed)
        if typed and typed ~= "" then
            revealed_buf = nil
        end
    end, vim.api.nvim_create_namespace("AsciidocPreviewKeys"))
    group = vim.api.nvim_create_augroup("AsciidocPreview", { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufEnter" }, {
        group = group,
        desc = "Tell asciidoc-lsp where the cursor is while a preview is open",
        callback = function(args)
            -- A revealLine never switches the buffer: entering one is the
            -- user's, also without a key (a double-click in the page).
            -- Moves after a reveal are dropped where the send happens.
            if args.event == "BufEnter" then
                revealed_buf = nil
            end
            if following_client(args.buf) then
                schedule_send()
            end
        end,
    })
end

local MODES = { "document", "part" }

--- Complete the optional mode argument of :AsciidocPreview.
function M.complete_modes(arg_lead)
    return vim.tbl_filter(function(mode)
        return vim.startswith(mode, arg_lead)
    end, MODES)
end

--- Open the preview of the current buffer in the browser. `mode` is
--- "document" (default) or "part".
function M.open(mode)
    mode = mode or "document"
    if not vim.tbl_contains(MODES, mode) then
        vim.notify(
            "AsciidocPreview: unknown mode '" .. mode .. "' (expected " .. table.concat(MODES, " or ") .. ")",
            vim.log.levels.ERROR
        )
        return
    end
    local bufnr = vim.api.nvim_get_current_buf()
    local client = vim.lsp.get_clients({ bufnr = bufnr, name = "asciidoc" })[1]
    if not client then
        vim.notify("AsciidocPreview: asciidoc-lsp is not attached to this buffer", vim.log.levels.ERROR)
        return
    end
    client:request("workspace/executeCommand", {
        command = "asciidoc.preview.open",
        arguments = { vim.uri_from_bufnr(bufnr), { mode = mode } },
    }, function(err, result)
        if err then
            vim.notify("AsciidocPreview: " .. err.message, vim.log.levels.ERROR)
            return
        end
        if type(result) ~= "table" or type(result.url) ~= "string" then
            vim.notify("AsciidocPreview: asciidoc-lsp returned no preview URL", vim.log.levels.ERROR)
            return
        end
        local _, open_err = vim.ui.open(result.url)
        if open_err then
            vim.notify("AsciidocPreview: " .. open_err .. " (" .. result.url .. ")", vim.log.levels.ERROR)
            return
        end
        open_clients[client.id] = true
        ensure_autocmds()
        send_cursor()
    end, bufnr)
end

--- Stop telling the server where the cursor is. The page stays as it is.
function M.stop()
    local bufnr = vim.api.nvim_get_current_buf()
    local client = following_client(bufnr)
    if not client then
        vim.notify("AsciidocPreviewStop: no preview is following this buffer", vim.log.levels.INFO)
        return
    end
    open_clients[client.id] = nil
    -- Clients that stopped while following (e.g. after :LspRestart) no
    -- longer count, or the autocmds would never go away.
    for id in pairs(open_clients) do
        local other = vim.lsp.get_client_by_id(id)
        if not other or other:is_stopped() then
            open_clients[id] = nil
        end
    end
    if next(open_clients) then
        return
    end
    if group then
        vim.api.nvim_del_augroup_by_id(group)
        group = nil
    end
    if timer then
        timer:stop()
        timer:close()
        timer = nil
    end
end

return M

-- :AsciidocPreview: open the live preview from asciidoc-lsp in the browser
-- and, from then on, tell the server where the cursor is so the page
-- follows it (`asciidoc/cursorMoved`).

local M = {}

local THROTTLE_MS = 100

-- Ids of the clients whose preview is open; the server ignores
-- cursorMoved without one, so nothing is sent before.
local open_clients = {}
local timer = nil
local group = nil

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
    if not client then
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

local function ensure_autocmds()
    if group then
        return
    end
    group = vim.api.nvim_create_augroup("AsciidocPreview", { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufEnter" }, {
        group = group,
        desc = "Tell asciidoc-lsp where the cursor is while a preview is open",
        callback = function(args)
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
        end
        open_clients[client.id] = true
        ensure_autocmds()
        send_cursor()
    end, bufnr)
end

return M

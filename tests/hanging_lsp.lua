-- A language server that never finishes shutting down, run with `nvim -l`.
-- It answers `initialize`, then stops reading at `shutdown` (or at the end of
-- its input) and idles until it is killed, as a server stuck in a handler
-- would. Its pid goes to the file named by the first argument.

local pid_file = assert(_G.arg[1], "usage: nvim -l hanging_lsp.lua <pid-file>")
local f = assert(io.open(pid_file, "w"))
f:write(tostring(vim.fn.getpid()))
f:close()

local function hang()
    while true do
        vim.wait(1000)
    end
end

local function read_message()
    local length
    while true do
        local line = io.stdin:read("*l")
        if line == nil then
            return nil
        end
        line = line:gsub("\r$", "")
        if line == "" then
            break
        end
        local value = line:match("^Content%-Length: (%d+)$")
        if value then
            length = tonumber(value)
        end
    end
    return vim.json.decode(io.stdin:read(length))
end

while true do
    local message = read_message()
    if message == nil or message.method == "shutdown" then
        hang()
    elseif message.method == "initialize" then
        local body = vim.json.encode({ jsonrpc = "2.0", id = message.id, result = { capabilities = vim.empty_dict() } })
        io.stdout:write("Content-Length: " .. #body .. "\r\n\r\n" .. body)
        io.stdout:flush()
    end
end

--- The workspace root of the asciidoc-lsp client for a file.
---
--- The server looks for top-level documents below the root, so the root has
--- to hold the whole project, as the opened folder does in VS Code or
--- IntelliJ. A config file is no project marker: `.asciidoctorconfig` files
--- also sit in subfolders, and a root there hides the documents that include
--- the folder's files.
local M = {}

local VCS_MARKERS = { ".git", ".jj", ".hg" }
local CONFIG_MARKERS = { ".asciidoctorconfig.adoc", ".asciidoctorconfig" }

--- The root for `path`, the first that applies:
--- 1. the repository that holds it (`.git`, `.jj`, `.hg`),
--- 2. `cwd`, if it holds the file and is not the home folder,
--- 3. the nearest folder with an `.asciidoctorconfig(.adoc)`,
--- 4. the file's own folder.
---@param path string absolute path of the file
---@param cwd string the working directory
---@return string
function M.find(path, cwd)
    local vcs = vim.fs.root(path, VCS_MARKERS)
    if vcs then
        return vcs
    end
    local home = vim.uv.os_homedir()
    if cwd ~= home and cwd ~= "/" and vim.fs.relpath(cwd, path) then
        return cwd
    end
    return vim.fs.root(path, CONFIG_MARKERS) or vim.fs.dirname(path)
end

--- `root_dir` for |vim.lsp.Config|: the root of the buffer's file, or of the
--- cwd for a buffer without a file name.
---@param bufnr integer
---@param on_dir fun(root_dir?: string)
function M.root_dir(bufnr, on_dir)
    local cwd = vim.fn.getcwd()
    local name = vim.api.nvim_buf_get_name(bufnr)
    on_dir(M.find(name ~= "" and name or cwd, cwd))
end

return M

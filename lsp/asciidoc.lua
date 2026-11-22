return {
    cmd = { 'asciidoc-lsp' },
    filetypes = { 'asciidoc' },
    root_markers = { '.asciidoctorconfig.adoc', '.asciidoctorconfig', '.git' },
    -- Let the server watch .asciidoctorconfig and .adoc files on disk.
    -- Neovim merges this into its default client capabilities.
    capabilities = {
        workspace = { didChangeWatchedFiles = { dynamicRegistration = true } },
    },
    -- The plugin highlights with treesitter. The server's semantic tokens
    -- (for editors without a tree-sitter highlighter) would be drawn over it,
    -- at a higher priority. Dropping the capability before the client
    -- attaches keeps Neovim from requesting them (:h lsp-semantic-highlight).
    on_init = function(client)
        client.server_capabilities.semanticTokensProvider = nil
    end,
    -- With the default (false) Neovim quits without waiting for the server
    -- and never kills it, so a server stuck in a handler keeps running.
    -- Give it a second to shut down, then force-stop it (:h vim.lsp.ClientConfig).
    exit_timeout = 1000,
}

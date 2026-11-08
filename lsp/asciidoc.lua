return {
    cmd = { 'asciidoc-lsp' },
    filetypes = { 'asciidoc' },
    root_markers = { '.asciidoctorconfig.adoc', '.asciidoctorconfig', '.git' },
    -- Let the server watch .asciidoctorconfig and .adoc files on disk.
    -- Neovim merges this into its default client capabilities.
    capabilities = {
        workspace = { didChangeWatchedFiles = { dynamicRegistration = true } },
    },
}

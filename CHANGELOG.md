# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Before 1.0, a minor version may contain breaking changes.

<!-- next-header -->

## [Unreleased]

## [0.3.1] - 2026-11-17

### Fixed

- Semantic tokens from asciidoc-lsp 0.8 no longer override Tree-sitter
  highlighting.

## [0.3.0] - 2026-11-15

### Added

- `:AsciidocDebug` shows how asciidoc-lsp resolves the position under the
  cursor, with the attributes known in each scope.
- Text objects `iS` and `aS` select a section.
- Inline formatting delimiters (`*strong*`, `_italic_`, `` `monospace` ``,
  `#highlighted#`) are concealed. Turn it off with `conceal.enable = false`.
- Changes to files on disk reach the language server.
- `:checkhealth asciidoc` checks that the bundled queries load with the
  installed parsers and which grammar revision each parser was built from.

### Changed

- Requires asciidoc-lsp 0.7.0 or later.
- `:checkhealth asciidoc` reports an asciidoc-lsp older than the required
  version.
- `treesitter.auto_install` now also updates parsers built from another
  grammar revision.
- The parsers come from the maintained tree-sitter-asciidoc fork, pinned to
  the commit the bundled queries are written for.
- Folding covers whole sections.
- Spellcheck covers prose only, not code, attributes or macros.
- A parser that does not fit the bundled queries no longer breaks the
  buffer; the plugin says which parser to update.

### Fixed

- Block anchors, attribute entries, tables, unfinished macros and orphan
  sections highlight correctly.
- Colors inside source blocks are kept.

## [0.2.0] - 2026-10-31

### Added

- Highlighting for line comments.

## [0.1.1] - 2026-05-01

### Fixed

- The language server starts for a file that triggers lazy loading of the
  plugin.

## [0.1.0] - 2026-03-09

### Added

- Highlighting, injections, folds and text objects for AsciiDoc through
  tree-sitter.
- File type detection and `:checkhealth asciidoc`.
- asciidoc-lsp starts automatically for AsciiDoc buffers.

<!-- next-url -->
[Unreleased]: https://github.com/seflue/asciidoc.nvim/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/seflue/asciidoc.nvim/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/seflue/asciidoc.nvim/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/seflue/asciidoc.nvim/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/seflue/asciidoc.nvim/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/seflue/asciidoc.nvim/commits/v0.1.0

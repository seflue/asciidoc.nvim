# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Before 1.0, a minor version may contain breaking changes.

<!-- next-header -->

## [Unreleased]

## [0.4.0] - 2026-11-23

### Added

- Section motions `]]`, `[[`, `][`, `[]`, `[u` and `]u` jump to the next,
  previous, sibling or parent section, or to the next section at the
  parent's level. Change the keys with `motions.keys`.
- Sections and blocks fold without fold configuration: the plugin sets
  `foldmethod` and `foldexpr` in AsciiDoc buffers (`folds.enable` turns this
  off). Sidebar, passthrough, markdown-style quote and comment blocks, CSV
  and DSV tables and description lists fold as well.
- Live preview: `:AsciidocPreview` and `:AsciidocPreviewStop`.

### Changed

- With Neovim's default `foldlevel` of 0, AsciiDoc files now open with every
  fold closed. Set `foldlevelstart` to open them unfolded.
- A section fold starts at the section title, so a closed fold shows the
  title instead of an anchor or attribute line above it.
- The workspace root is the repository (`.git`, `.jj`, `.hg`), then the
  current directory, before the nearest `.asciidoctorconfig`. A config file
  in a subfolder no longer makes that folder the root, which hid the
  documents that include its files and the images outside it.
- Spellcheck covers paragraphs in quote blocks and skips `pass:[]` macros.
- `:checkhealth asciidoc` recognizes local server builds
  (`X.Y.Z+<commits>.<hash>`) and warns about a build without a release tag.

### Fixed

- Highlighting: listings without a style, literal blocks, every paragraph of
  an admonition block, source styles, autolink brackets and revision lines.
  Prose words such as "link" no longer look like macros.
- Quitting Neovim stops a language server that hangs on shutdown.

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
[Unreleased]: https://github.com/seflue/asciidoc.nvim/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/seflue/asciidoc.nvim/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/seflue/asciidoc.nvim/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/seflue/asciidoc.nvim/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/seflue/asciidoc.nvim/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/seflue/asciidoc.nvim/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/seflue/asciidoc.nvim/commits/v0.1.0

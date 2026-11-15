; textobjects.scm for asciidoc (block-level grammar)
; asciidoc.nvim — Compatible with nvim-treesitter-textobjects
; Parser: seflue/tree-sitter-asciidoc (main)

; =============================================================================
; --- Sections ---
; =============================================================================

; @section.outer — entire section (header + content, nested sections included)
(section) @section.outer

; @section.inner — section content without title
; Block attributes, block titles or comments may precede the title inside the
; section, so anchor on the title itself; the quantified capture spans from
; the first to the last node after it. A section with only a title has no
; inner range.
(section
  [
    (title1)
    (title2)
    (title3)
    (title4)
    (title5)
  ]
  .
  (_)+ @section.inner)

; =============================================================================
; --- Delimiter Blocks ---
; =============================================================================

; @block.outer — entire delimiter block (including delimiters)
(listing_block) @block.outer
(literal_block) @block.outer
(delimited_block) @block.outer
(open_block) @block.outer
(quoted_block) @block.outer

; @block.inner — block body (without delimiters)
(listing_block
  (listing_block_body) @block.inner)
(literal_block
  (literal_block_body) @block.inner)

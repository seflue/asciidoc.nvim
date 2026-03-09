; textobjects.scm for asciidoc (block-level grammar)
; asciidoc.nvim — Compatible with nvim-treesitter-textobjects
; Parser: cathaysia/tree-sitter-asciidoc

; =============================================================================
; --- Sections ---
; =============================================================================

; @section.outer — entire section (header + content)
(section_block) @section.outer

; @section.inner — section content without title
; Requires :InspectTree validation of section_block's child nodes.
; The cathaysia grammar's exact children (title node type, content wrapper)
; are unverified — a wrong pattern here blocks the entire parser (see spike
; adoc-0076, Erkenntnis 4). Add the pattern once node structure is confirmed.

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

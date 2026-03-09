; highlights.scm for asciidoc_inline
; asciidoc.nvim — Parser: cathaysia/tree-sitter-asciidoc (inline grammar)

; =============================================================================
; --- Text Formatting ---
; =============================================================================

; *bold*
(emphasis) @markup.strong

; _italic_
(ltalic) @markup.italic

; `monospace`
(monospace) @markup.raw

; #highlighted# or [.role]#text#
(highlight) @markup.mark

; =============================================================================
; --- Links ---
; =============================================================================

; https://example.com (bare URLs)
(autolink) @markup.link.url

; URI component
(uri) @markup.link.url

; Link label text
(uri_label) @markup.link.label

; https://example.com[Label]
(labled_uri) @markup.link

; email addresses
(email) @markup.link.url

; =============================================================================
; --- Cross-References ---
; =============================================================================

; <<anchor>> or <<anchor,display text>>
(xref) @markup.link
(xref
  "<<" @punctuation.special
  ">>" @punctuation.special)
(xref
  (reftext) @markup.link.label)

; =============================================================================
; --- Inline Macros ---
; =============================================================================

; xref:target[display text] — cross-reference macro (link-style)
(inline_macro
  (macro_name) @_name
  (#eq? @_name "xref")
  (target) @markup.link
  (attr) @markup.link.label)
(inline_macro
  (macro_name) @_name
  (#eq? @_name "xref")
  "[" @punctuation.special
  "]" @punctuation.special)

; Other macros: kbd:[Ctrl+C], btn:[OK], menu:File[Save], image:path[]
(inline_macro
  (macro_name) @function.macro
  (target) @string.special.path)

; Passthrough macros
(macro_passthrough) @markup.raw

; Stem macros (math)
(stem_macro) @markup.math

; =============================================================================
; --- Anchors / IDs ---
; =============================================================================

; [[anchor-id]]
(id_assignment) @tag
(id_assignment
  "[[" @punctuation.special
  "]]" @punctuation.special)

; =============================================================================
; --- Passthrough ---
; =============================================================================

; +passthrough+ or +++passthrough+++
(passthrough) @markup.raw

; =============================================================================
; --- Special Content ---
; =============================================================================

; Character replacements (arrows, dashes, etc.)
(replacement) @string.special

; Footnotes
(footnote) @markup.note

; Escaped sequences
(escaped_sequence) @string.escape

; =============================================================================
; --- Attribute References ---
; =============================================================================

; {attribute-name}
(intrinsic_attributes) @variable

; Index terms
(index_term) @keyword
(index_term2) @keyword

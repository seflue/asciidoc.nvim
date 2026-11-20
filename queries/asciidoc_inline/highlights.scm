[
  (monospace)
  (passthrough)
] @markup.raw @nospell

(emphasis) @markup.strong

(italic) @markup.italic

(highlight) @markup.italic

(superscript) @markup.superscript

(subscript) @markup.subscript

[
  (link_url)
  (email)
] @markup.link.url @markup.link

(uri_label) @markup.link.label

; The angle brackets of `<https://example.org>` are markup: Asciidoctor drops
; them from the output.
(autolink
  [
    "<"
    ">"
  ] @punctuation.bracket)

[
  "["
  "]"
  "{"
  "}"
  "<<" @punctuation.bracket
  ">>" @punctuation.bracket
] @punctuation.bracket

":" @punctuation.delimiter

(replacement) @string.special

(roled_text
  (role) @attribute)

(attribute_reference
  (attribute_name) @constant)

(xref
  (reftext) @markup.link @markup.link.url)

(xref
  (id) @markup.link @markup.link.url .)

(xref
  (id) @markup.link.label
  (reftext) @markup.link @markup.link.url)

; A word such as "link" in prose is a `macro_name` too, so only a macro's
; own name is a keyword.
(inline_macro
  (macro_name) @keyword)

(footnote
  (macro_name) @keyword)

(stem_macro
  (macro_name) @keyword)

(macro_passthrough
  (macro_name) @keyword)

[
  "((("
  ")))"
  "(("
  "))"
] @keyword

(inline_macro
  (target) @label)

(inline_macro
  (attr) @attribute)

(escaped_sequence) @string.escape

(inline_macro
  (target)? @markup.link @markup.link.url
  (attr)? @label)

(stem_macro
  (target)? @label
  (attr)? @markup.raw @nospell)

(footnote
  (target)? @label
  (attr) @attribute)

; The value of a named macro attribute (e.g. `window=_blank`).
(named_attr
  (attribute_value) @string)

(term) @attribute

(id_assignment) @label

(super_escape) @string.special

(hard_wrap) @punctuation.special

; Spell: (line) in the block grammar marks all inline text as @spell, so
; everything technical inside it opts out here. Scope macro_name to its parents:
; it also occurs inside plain (word) nodes.
[
  (attribute_reference)
  (email)
  (id)
  (id_assignment)
  (link_url)
  (named_attr)
  (role)
  (target)
] @nospell

(inline_macro
  (macro_name) @nospell)

(footnote
  (macro_name) @nospell)

(stem_macro
  (macro_name) @nospell)

; These take keys and UI labels, not prose.
((inline_macro
  (macro_name) @_name
  (attr) @nospell)
  (#any-of? @_name "kbd" "btn" "menu" "icon"))

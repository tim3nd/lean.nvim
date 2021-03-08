; Variables
(identifier) @variable

;; Identifier naming conventions
((identifier) @type
 (#match? @type "^[A-Z]"))

(function_type) @type
(product_type) @type
(inductive_type) @type

(instance
  class: (identifier) @type)
(instance_field
  return_type: (identifier) @type)

;; Definitions

(def
  name: (identifier) @function)

(def
  attributes: (identifier) @function)

(apply
  name: (identifier) @function)

(field_of
  name: (identifier) @method)

(parameters
  type: (identifier) @type)

(inductive_constructor) @constructor

["if" "then" "else"] @conditional

["for" "in" "do"] @repeat

(import) @include

; Tokens

[
  "!"
  "$"
  "%"
  "&&"
  "*"
  "+"
  "++"
  "-"
  "/"
  "::"
  ":="
  "<"
  "<="
  "<|"
  "<|>"
  "="
  "=="
  "=>"
  ">"
  ">"
  ">="
  "@"
  "^"
  "|>"
  "|>."
  "||"
  "←"
  "→"
  "↔"
  "∧"
  "∨"
  "≠"
  "≤"
  "≥"
] @operator

[
  "by"
  "end"
  "export"
  "fun"
  "let"
  "match"
  "namespace"
  "open"
  "return"
  "section"
  "structure"
  "universe"
  "variable"
  "where"
  "with"
  "λ"
  (hash_command)
  (prelude)
  (sorry)
] @keyword

[
  "class"
  "constant"
  "def"
  "example"
  "inductive"
  "instance"
  "theorem"
] @keyword.decl

[
  "noncomputable"
  "partial"
  "private"
  "protected"
  "unsafe"
] @keyword.modifier

[
  "exact"
  "rewrite"
  "simp"
] @keyword.tactic

[
  "catch"
  "finally"
  "try"
] @exception

[
  "throw"
  "mut"
] @keyword

[(true) (false)] @boolean

(number) @number
(float) @float

(comment) @comment
(char) @number
(string) @string
(interpolated_string) @string

; Reset highlighing in string interpolation
(interpolation) @none

["(" ")" "[" "]" "{" "}" "⟨" "⟩"] @punctuation.bracket

(interpolation
  "{" @punctuation.special
  "}" @punctuation.special)

["," "." ":"] @punctuation.delimiter

(sorry) @error

;; Error
(ERROR) @error

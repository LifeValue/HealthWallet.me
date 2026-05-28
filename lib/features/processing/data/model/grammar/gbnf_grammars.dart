class GbnfGrammars {
  GbnfGrammars._();

  static String get jsonArray => r'''
root        ::= "[" ws object ("," ws object)* ws "]"
object      ::= "{" ws pair ("," ws pair)* ws "}"
pair        ::= string ws ":" ws value
value       ::= string | number | "true" | "false" | "null" | object | array
array       ::= "[" ws (value ("," ws value)*)? ws "]"
string      ::= "\"" chars "\""
chars       ::= char*
char        ::= [^"\\\x00-\x1f] | "\\" escape
escape      ::= ["\\nrt/bf] | "u" hexdig hexdig hexdig hexdig
hexdig      ::= [0-9a-fA-F]
number      ::= "-"? int frac? exp?
int         ::= "0" | [1-9] [0-9]*
frac        ::= "." [0-9]+
exp         ::= [eE] [+-]? [0-9]+
ws          ::= [ \t\n]*
''';
}

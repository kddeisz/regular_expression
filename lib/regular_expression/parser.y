# frozen_string_literal: true

class RegularExpression::Parser
rule
  target:
    root
    { result = val[0] }
    | /* none */
    { result = nil }

  root:
    CARET expression
    { result = AST::Root.new(val[1], at_start: true) }
    | expression
    { result = AST::Root.new(val[0]) }

  expression:
    subexpression PIPE expression
    { result = [AST::Expression.new(val[0])] + val[2] }
    | subexpression
    { result = [AST::Expression.new(val[0])] }

  subexpression:
    item subexpression
    { result = [val[0]] + val[1] }
    | item
    { result = [val[0]] }

  item:
    group
    | match
    | ANCHOR
    { result = AST::Anchor.new(val[0]) }

  group:
    LPAREN expression RPAREN quantifier
    { result = AST::CaptureGroup.new(val[1], quantifier: val[3]) }
    | LPAREN expression RPAREN
    { result = AST::CaptureGroup.new(val[1]) }
    | NO_CAPTURE expression RPAREN quantifier
    { result = AST::Group.new(val[1], quantifier: val[3]) }
    | NO_CAPTURE expression RPAREN
    { result = AST::Group.new(val[1]) }
    | NAMED_CAPTURE expression RPAREN
    { result = AST::CaptureGroup.new(val[1], name: val[0]) }
    | NAMED_CAPTURE expression RPAREN quantifier
    { result = AST::CaptureGroup.new(val[1], quantifier: val[3], name: val[0]) }

  match:
    match_item quantifier
    { result = AST::Match.new(val[0], quantifier: val[1]) }
    | match_item
    { result = AST::Match.new(val[0]) }

  match_item:
    LBRACKET CARET character_group_items RBRACKET
    { result = AST::CharacterGroup.new(val[2], invert: true) }
    | LBRACKET character_group_items RBRACKET
    { result = AST::CharacterGroup.new(val[1]) }
    | CHAR_CLASS
    { result = AST::CharacterClass.new(val[0]) }
    | CHAR_TYPE
    { result = AST::CharacterType.new(val[0]) }
    | DASH
    { result = AST::Character.new(val[0]) }
    | PERIOD
    { result = AST::Period.new }
    | POSITIVE_LOOKAHEAD assertion_items RPAREN
    { result = AST::PositiveLookahead.new(val[1]) }
    | NEGATIVE_LOOKAHEAD assertion_items RPAREN
    { result = AST::NegativeLookahead.new(val[1]) }
    | character

  character_group_items:
    character_group_item character_group_items
    { result = [val[0]] + val[1] }
    | character_group_item
    { result = [val[0]] }

  character_group_item:
    CHAR_CLASS
    { result = AST::CharacterClass.new(val[0]) }
    | CHAR DASH CHAR
    { result = AST::CharacterRange.new(val[0], val[2]) }
    | character

  assertion_items:
    character assertion_items
    { result = [val[0]] + val[1] }
    | character
    { result = [val[0]] }

  character:
    CHAR
    { result = AST::Character.new(val[0]) }
    | COMMA
    { result = AST::Character.new(val[0]) }
    | DIGIT
    { result = AST::Character.new(val[0]) }

  quantifier:
    LBRACE integer COMMA integer RBRACE
    { result = AST::Quantifier::Range.new(val[1], val[3]) }
    | LBRACE integer COMMA RBRACE
    { result = AST::Quantifier::AtLeast.new(val[1]) }
    | LBRACE COMMA integer RBRACE
    { result = AST::Quantifier::Range.new(0, val[2]) }
    | LBRACE integer RBRACE
    { result = AST::Quantifier::Exact.new(val[1]) }
    | STAR
    { result = AST::Quantifier::ZeroOrMore.new }
    | PLUS
    { result = AST::Quantifier::OneOrMore.new }
    | QMARK
    { result = AST::Quantifier::Optional.new }

  integer:
    digits
    { result = val[0].to_i }

  digits:
    DIGIT digits
    { result = val[0] + val[1] }
    | DIGIT
    { result = val[0] }

end

---- inner

  def parse(str, flags = Flags.new)
    @tokens = Lexer.new(str, flags).tokens
    do_parse
  end

  def next_token
    @tokens.shift
  end

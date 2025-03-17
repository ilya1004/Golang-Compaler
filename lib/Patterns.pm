package Patterns;
use strict;
use warnings;

sub getTokenTypesList {

    my @comments = (
        { Name => "comment",    Regex => "\\/\\/.*", Class => "skip" },
    );

    # Ключевые слова
    my @keywords = (
        { Name => "package",     Regex => "package",     Class => "keyword" },
        { Name => "import",      Regex => "import",      Class => "keyword" },
        { Name => "func",        Regex => "func",        Class => "keyword" },
        { Name => "if",          Regex => "if",          Class => "keyword" },
        { Name => "else",        Regex => "else",        Class => "keyword" },
        { Name => "for",         Regex => "for",         Class => "keyword" },
        { Name => "return",      Regex => "return",      Class => "keyword" },
        { Name => "var",         Regex => "var",         Class => "keyword" },
        { Name => "const",       Regex => "const",       Class => "keyword" },
        { Name => "break",       Regex => "break",       Class => "keyword" },
        { Name => "case",        Regex => "case",        Class => "keyword" },
        { Name => "chan",        Regex => "chan",        Class => "keyword" },
        { Name => "continue",    Regex => "continue",    Class => "keyword" },
        { Name => "default",     Regex => "default",     Class => "keyword" },
        { Name => "defer",       Regex => "defer",       Class => "keyword" },
        { Name => "fallthrough", Regex => "fallthrough", Class => "keyword" },
        { Name => "go",          Regex => "go",          Class => "keyword" },
        { Name => "goto",        Regex => "goto",        Class => "keyword" },
        { Name => "interface",   Regex => "interface",   Class => "keyword" },
        { Name => "map",         Regex => "map",         Class => "keyword" },
        { Name => "range",       Regex => "range",       Class => "keyword" },
        { Name => "select",      Regex => "select",      Class => "keyword" },
        { Name => "struct",      Regex => "struct",      Class => "keyword" },
        { Name => "switch",      Regex => "switch",      Class => "keyword" },
        { Name => "type",        Regex => "type",        Class => "keyword" },
        { Name => "bool",        Regex => "bool",        Class => "keyword" },
        { Name => "string",      Regex => "string",      Class => "keyword" },
        { Name => "int",         Regex => "int",         Class => "keyword" },
        { Name => "int8",        Regex => "int8",        Class => "keyword" },
        { Name => "int16",       Regex => "int16",       Class => "keyword" },
        { Name => "int32",       Regex => "int32",       Class => "keyword" },
        { Name => "int64",       Regex => "int64",       Class => "keyword" },
        { Name => "uint",        Regex => "uint",        Class => "keyword" },
        { Name => "uint8",       Regex => "uint8",       Class => "keyword" },
        { Name => "uint16",      Regex => "uint16",      Class => "keyword" },
        { Name => "uint32",      Regex => "uint32",      Class => "keyword" },
        { Name => "uint64",      Regex => "uint64",      Class => "keyword" },
        { Name => "float32",     Regex => "float32",     Class => "keyword" },
        { Name => "float64",     Regex => "float64",     Class => "keyword" },
    );
    
    # Операторы
    my @operators = (
        { Name => "dot",         Regex => "\\.", Class => "operator" },
        
        { Name => "plus_assign", Regex => "\\+=",Class => "operator" },
        { Name => "increment",   Regex => "\\+\\+",Class => "operator" },
        { Name => "plus",        Regex => "\\+", Class => "operator" },

        { Name => "minus_assign",Regex => "\\-=",Class => "operator" },
        { Name => "decrement",   Regex => "\\-\\-",Class => "operator" },
        { Name => "minus",       Regex => "\\-", Class => "operator" },
        
        { Name => "mul_assign",  Regex => "\\*=",Class => "operator" },
        { Name => "multiply",    Regex => "\\*", Class => "operator" },
        
        { Name => "div_assign",  Regex => "\\/=",Class => "operator" },
        { Name => "divide",      Regex => "\\/", Class => "operator" },
        
        { Name => "equal",       Regex => "==",  Class => "operator" },
        { Name => "assignment",  Regex => "=",   Class => "operator" },
        
        { Name => "not_equal",   Regex => "!=",  Class => "operator" },
        { Name => "logical_not", Regex => "!",   Class => "operator" },
        
        { Name => "logical_or",  Regex => "\\|\\|",Class => "operator" },
        { Name => "bitwise_or",  Regex => "\\|", Class => "operator" },

        { Name => "logical_and", Regex => "&&",  Class => "operator" },
        { Name => "bitwise_and", Regex => "&",   Class => "operator" },

        { Name => "greater_equal",Regex => ">=", Class => "operator" },
        { Name => "bitwise_shr", Regex => ">>",  Class => "operator" },
        { Name => "greater",     Regex => ">",   Class => "operator" },

        { Name => "less_equal",  Regex => "<=",  Class => "operator" },
        { Name => "bitwise_shl", Regex => "<<",  Class => "operator" },
        { Name => "less",        Regex => "<",   Class => "operator" },

        { Name => "modulo",      Regex => "%",   Class => "operator" },
        { Name => "bitwise_xor", Regex => "\\^", Class => "operator" },
        { Name => "declaration", Regex => ":=",  Class => "operator" },
    );
    
    # Идентификаторы
    my @identifiers = (
        { Name => "id-", Regex => "[A-Za-z_][A-Za-z0-9_]*", Class => "identifier" },
    );
    
    # Константы: числа и строковые литералы
    my @constants = (
        { Name => "number", Regex => "[+-]?\\d+(\\.\\d+)?([eE][+-]?\\d+)?", Class => "constant" },
        { Name => "string", Regex => '"(?:\\\.|[^"\\n\\\])*"', Class => "constant" },
    );
    
    # Знаки препинания
    my @punctuations = (
        { Name => "l_paren",   Regex => "\\(", Class => "punctuation" },
        { Name => "r_paren",   Regex => "\\)", Class => "punctuation" },
        { Name => "l_brace",   Regex => "\\{", Class => "punctuation" },
        { Name => "r_brace",   Regex => "\\}", Class => "punctuation" },
        { Name => "l_bracket", Regex => "\\[", Class => "punctuation" },
        { Name => "r_bracket", Regex => "\\]", Class => "punctuation" },
        { Name => "comma",     Regex => ",",  Class => "punctuation" },
        { Name => "semicolon", Regex => ";",  Class => "punctuation" },
        { Name => "colon",     Regex => ":",  Class => "punctuation" },
        { Name => "newline", Regex => "\\n+", Class => "punctuation" },
    );
    
    # Пропускаемые токены: пробельные символы и комментарии
    my @skip = (
        { Name => "whitespace", Regex => "\\s+", Class => "skip" },
    );
    
    my @tokenTypesList = (@comments, @keywords, @constants, @operators, @identifiers, @punctuations, @skip);
    return @tokenTypesList;
}

1;

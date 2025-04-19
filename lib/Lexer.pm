package Lexer;
use strict;
use warnings;
use Data::Dumper;

use Patterns;


sub new {
    my ($class, $code) = @_;
    my $self = {
        Code                  => $code,
        Pos                   => 0,
        TokenList             => [],
        KeywordsTokenList     => [],
        OperatorsTokenList    => [],
        IdentifiersTokenList  => [],
        ConstantsTokenList    => [],
        PunctuationsTokenList => [],
    };
    bless $self, $class;
    return $self;
}


sub lex_analyze {
    my ($self) = @_;
    while (1) {
        my ($res, $err) = $self->next_token();
        if (defined $err && $err ne "") {
            warn $err, "\n";
            last;
        }
        last unless $res;

        if (@{$self->{TokenList}} > 1) {
            my $prev_token = $self->{TokenList}[-2];
            my $last_token = $self->{TokenList}[-1];
            if ($last_token->{Name} eq 'newline' && should_insert_semicolon($prev_token)) {
                $last_token->{Name} = 'semicolon';
                $last_token->{Text} = ';';
                $last_token->{Class} = 'punctuation';
            }
        }
    }
    
    $self->{TokenList} = [grep { !should_remove_newline($_, $self->{TokenList}) } @{$self->{TokenList}}];
    
    if (should_insert_semicolon($self->{TokenList}[-1])) {
        push @{ $self->{TokenList} }, { Name => 'semicolon', Text => ';', Line => 0, Column => 0, Pos => 0, Class => 'punctuation' };
    }
    
    if ($self->{TokenList}[-1]->{Name} ne 'EOF') {
        push @{ $self->{TokenList} }, { Name => 'EOF', Text => 'EOF', Line => 0, Column => 0, Pos => 0, Class => 'EOF' };
    }
    return $self->{TokenList};
}

sub should_insert_semicolon {
    my ($token) = @_;
    return ($token->{Class} eq 'identifier' ||
            $token->{Class} eq 'constant' ||
            $token->{Name} eq 'break' ||
            $token->{Name} eq 'continue' ||
            $token->{Name} eq 'return' ||
            $token->{Name} eq 'fallthrough' ||
            $token->{Name} eq 'r_paren' ||
            $token->{Name} eq 'r_bracket' ||
            $token->{Name} eq 'r_brace' ||
            $token->{Name} eq 'bool' ||
            $token->{Name} eq 'string' ||
            $token->{Name} eq 'int' ||
            $token->{Name} eq 'int8' ||
            $token->{Name} eq 'int16' ||
            $token->{Name} eq 'int32' ||
            $token->{Name} eq 'int64' ||
            $token->{Name} eq 'uint' ||
            $token->{Name} eq 'uint8' ||
            $token->{Name} eq 'uint16' ||
            $token->{Name} eq 'uint32' ||
            $token->{Name} eq 'uint64' ||
            $token->{Name} eq 'float32' ||
            $token->{Name} eq 'float64');
}

sub should_remove_newline {
    my ($token, $token_list) = @_;
    my $index = 0;
    $index++ while $index < @$token_list && $token_list->[$index] != $token;
    return $token->{Name} eq 'newline' && (
        $index == 0 ||
        $token_list->[$index - 1]->{Name} =~ /^(l_paren|l_brace|comma|operator|semicolon|newline|colon|increment|decrement)$/
    );
}

sub next_token {
    my ($self) = @_;
    my $code = $self->{Code};
    my $pos  = $self->{Pos};
    if ($pos >= length($code)) {
        return (0, ""); 
    }
    my $text = substr($code, $pos);
    
    foreach my $tokenType (Patterns::getTokenTypesList()) {
        my $pattern = '^(' . $tokenType->{Regex} . ')';
        if ($text =~ /$pattern/) {
            my $firstMatch = $1;
            my $suffix = "";
            if ($tokenType->{Class} eq "identifier") {
                if (exists $main::ids{$firstMatch}) {
                    $suffix = $main::ids{$firstMatch};
                } else {
                    $suffix = $main::index;
                    $main::ids{$firstMatch} = $main::index;
                    $main::index++;
                }
            }
            my ($line, $col) = char_to_line_col($code, $pos);
            my $name = $tokenType->{Name};
            if ($tokenType->{Class} eq "identifier") {
                $name .= $suffix; 
            }
          
            my %token = (
                Name   => $name,
                Text   => $firstMatch,
                Class  => $tokenType->{Class},
                Pos    => $pos,
                Line   => $line,
                Column => $col,
            );
            
            $self->{Pos} += length($firstMatch);
         
            if ($tokenType->{Class} ne "skip") {
                push @{$self->{TokenList}}, \%token;
            }
           
            if ($tokenType->{Class} eq "keyword") {
                push @{$self->{KeywordsTokenList}}, \%token;
            } elsif ($tokenType->{Class} eq "operator") {
                push @{$self->{OperatorsTokenList}}, \%token;
            } elsif ($tokenType->{Class} eq "identifier") {
                push @{$self->{IdentifiersTokenList}}, \%token;
            } elsif ($tokenType->{Class} eq "constant") {
                push @{$self->{ConstantsTokenList}}, \%token;
            } elsif ($tokenType->{Class} eq "punctuation") {
                push @{$self->{PunctuationsTokenList}}, \%token;
            }
            return (1, "");
        }
    }

    my ($line, $col) = char_to_line_col($code, $pos);
    my ($err_text) = ($text =~ /^(\S+)/);
    $err_text //= "";
    return (1, "Ошибка на строке $line, колонке $col: неожиданный токен '$err_text'");
}


sub char_to_line_col {
    my ($s, $charIndex) = @_;
    my $line = 1;
    my $col  = 1;
    for my $i (0 .. $charIndex - 1) {
        my $ch = substr($s, $i, 1);
        if ($ch eq "\n") {
            $line++;
            $col = 1;
        } else {
            $col++;
        }
    }
    return ($line, $col);
}

1;

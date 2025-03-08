package Lexer;
use strict;
use warnings;

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
    }
    
    # Если EOF не добавлен лексером, добавляем его здесь
    if ($self->{TokenList}[-1]->{Name} ne 'EOF') {
        push @{ $self->{TokenList} }, { Name => 'EOF', Text => '', Line => 0, Column => 0, Pos => 0, Class => 'EOF' };
    }
    return $self->{TokenList};
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

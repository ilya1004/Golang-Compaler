package Parser;

use strict;
use warnings;

use Data::Dumper;

# Конструктор парсера
sub new {
    my ( $class, $tokens ) = @_;
    my $self = {
        tokens => $tokens,    # Список токенов от лексера
        pos    => 0,          # Текущая позиция в списке токенов
    };
    bless $self, $class;
    return $self;
}

sub get_table_value {
    my ( $self, $action_table, $state, $token_name ) = @_;
    $token_name = $token_name =~ /^id-\d+$/ ? 'id' : $token_name;
    return
      exists $action_table->{$state}{$token_name}
      ? $action_table->{$state}{$token_name}
      : undef;
}

# Основной метод парсинга
sub parse {
    my ($self) = @_;

    my @state_stack = (0);
    my @value_stack = ();
    my $pos         = 0;

     
    # $action_table{state}{token} = [ action_type, value ];
    # state — текущее состояние автомата.
    # token — текущий входной токен.
    # action_type — тип действия:
    #   'shift' — перейти в новое состояние (value указывает номер состояния).
    #   'reduce' — свернуть цепочку (value указывает номер правила в rules).
    #   'accept' — завершить парсинг.
    
    my %action_table = (
        0 => {
            'id'     => [ 'shift', 2 ],
            'l_paren' => [ 'shift', 3 ]
        },
        1 => {
            'EOF' => [ 'accept', 0 ]
        },
        2 => {
            'plus' => [ 'shift',  4 ],
            'EOF'  => [ 'reduce', 1 ]
        },
        3 => {
            'id'     => [ 'shift', 2 ],
            'l_paren' => [ 'shift', 3 ]
        },
        4 => {
            'id'     => [ 'shift', 2 ],
            'l_paren' => [ 'shift', 3 ]
        },
    );

    # $goto_table{state}{nonterminal} = new_state;
    # state — текущее состояние автомата.
    # nonterminal — нетерминал, полученный после reduce.
    # new_state — состояние, в которое нужно перейти.
    my %goto_table = (
        0 => { 'EXPR' => 1 },
        3 => { 'EXPR' => 5 },
        4 => { 'EXPR' => 6 },
    );

    # $rules{rule_id} = [ lhs, rhs_count ];
    # rule_id — номер правила.
    # lhs — нетерминал, который получается после свертки.
    # rhs_count — сколько элементов убрать из value_stack.
    my %rules = (
        1 => [ 'EXPR', 1 ],
        2 => [ 'EXPR', 3 ],
        3 => [ 'EXPR', 3 ],
    );

    while (1) {
        my $current_state = $state_stack[-1];
        my $current_token = $self->{tokens}->[$pos];
        my $token_name    = $current_token->{Name};

        my $action =
          $self->get_table_value( \%action_table, $current_state, $token_name );

        print Dumper($current_token);

        if ($action) {
            my ( $action_type, $action_state ) = @$action;

            if ( $action_type eq 'shift' ) {
                push @state_stack, $action_state;
                push @value_stack, $current_token;
                $pos++;
            }
            elsif ( $action_type eq 'reduce' ) {
                my ( $lhs, $rhs_count ) = @{ $rules{$action_state} };
                my @children;
                for ( 1 .. $rhs_count ) {
                    pop @state_stack;
                    unshift @children, pop @value_stack;
                }
                my $node = { type => $lhs, children => \@children };
                my $next_state =
                  $self->get_table_value( \%goto_table, $state_stack[-1], $lhs );
                push @state_stack, $next_state;
                push @value_stack, $node;
            }
            elsif ( $action_type eq 'accept' ) {
                return $value_stack[0];
            }
        }
        else {
            die
"Ошибка парсинга: неожиданный токен '$current_token->{Text}' на строке $current_token->{Line}, колонке $current_token->{Column}\n";
        }
    }
}

1;

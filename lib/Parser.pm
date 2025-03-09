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
            'id'      => [ 'shift', 5 ], 
            'l_paren' => [ 'shift', 4 ]
        },

        1 => {
            'plus'     => [ 'shift',  6 ],
            'new_line' => [ 'accept', 0 ],
            'EOF'      => [ 'accept', 0 ],  # add
        },

        2 => {
            'plus'     => [ 'reduce', 2 ],
            'minus'    => [ 'reduce', 2 ],  # add
            'multiply' => [ 'shift', 7 ],
            'divide'   => [ 'shift', 7 ],   # add
            'r_paren'  => [ 'reduce', 2 ],
            'new_line' => [ 'reduce', 2 ],
        },

        3 => {
            'plus'     => [ 'reduce', 4 ],
            'minus'    => [ 'reduce', 4 ],  # add
            'multiply' => [ 'reduce', 4 ],
            'divide'   => [ 'reduce', 4 ],  # add
            'r_paren'  => [ 'reduce', 4 ],
            'new_line' => [ 'reduce', 4 ],
            'EOF'      => [ 'reduce', 4 ],  # add
        },

        4 => {
            'id'      => [ 'shift', 5 ],
            'l_paren' => [ 'shift', 4 ],
        },

        5 => {
            'plus'     => [ 'reduce', 6 ],
            'minus'    => [ 'reduce', 6 ],  # add
            'multiply' => [ 'reduce', 6 ],
            'divide'   => [ 'reduce', 6 ],  # add
            'r_paren'  => [ 'reduce', 6 ],
            'new_line' => [ 'reduce', 6 ],
            'EOF'      => [ 'reduce', 6 ],  # add
        },

        6 => {
            'id'       => [ 'shift', 5 ],
            'l_paren'  => [ 'shift', 4 ],
        },

        7 => {
            'id'       => [ 'shift', 5 ],
            'l_paren'  => [ 'shift', 4 ],
        },

        8 => {
            'plus'     => [ 'shift', 6  ],
            'minus'    => [ 'shift', 6  ],   # add
            'r_paren'  => [ 'shift', 11 ],
        },

        9 => {
            'plus'     => [ 'reduce', 1 ],
            'minus'    => [ 'reduce', 1 ],  # add
            'multiply' => [ 'shift',  7 ],
            'divide'   => [ 'shift',  7 ],  # add
            'r_paren'  => [ 'reduce', 1 ],
            'new_line' => [ 'reduce', 1 ],
            'EOF'      => [ 'reduce', 1 ],  # add
        },

        10 => {
            'plus'     => [ 'reduce', 3 ],
            'minus'    => [ 'reduce', 3 ],  # add
            'multiply' => [ 'shift',  3 ],
            'divide'   => [ 'shift',  3 ],  # add
            'r_paren'  => [ 'reduce', 3 ],
            'new_line' => [ 'reduce', 3 ],
            'EOF'      => [ 'reduce', 3 ],  # add
        },

        11 => {
            'plus'     => [ 'reduce', 5 ],
            'minus'    => [ 'reduce', 5 ],  # add
            'multiply' => [ 'shift',  5 ],
            'divide'   => [ 'shift',  5 ],  # add
            'r_paren'  => [ 'reduce', 5 ],
            'new_line' => [ 'reduce', 5 ],
            'EOF'      => [ 'reduce', 5 ],  # add
        },
        
    );

    # Выбран reduce

    # $rules{action_state} = [ lhs, rhs_count ];
    # actions_state — текущее состояние (номер правила).
    # lhs — нетерминал, который получается после свертки.
    # rhs_count — сколько элементов убрать из value_stack.
    my %rules = (
        1 => [ 'EXPR', 3 ],    # EXPR → EXPR + TERM
        2 => [ 'EXPR', 1 ],    # EXPR → TERM 
        3 => [ 'TERM', 3 ],    # TERM → TERM * FACTOR
        4 => [ 'TERM', 1 ],    # TERM → FACTOR
        5 => [ 'FACTOR', 3 ],  # FACTOR → ( EXPR )
        6 => [ 'FACTOR', 1 ],  # FACTOR → id
        
    );

    # $goto_table{state}{nonterminal} = new_state;
    # state — текущее состояние автомата.
    # nonterminal — нетерминал, полученный после reduce.
    # new_state — состояние, в которое нужно перейти.
    my %goto_table = (
        0 => {
            'EXPR'   => 1,
            'TERM'   => 2,
            'FACTOR' => 3,
        },

        2 => {
            'TERM'   => 2,
        },

        4 => { 
            'EXPR'   => 8,
            'TERM'   => 2,
            'FACTOR' => 3, 
        },

        6 => { 
            'TERM'   => 9,
            'FACTOR' => 3,
        },
        7 => { 
            'FACTOR' => 10,
        },
    );


    while (1) {
        my $current_state = $state_stack[-1];
        my $current_token = $self->{tokens}->[$pos];
        my $token_name    = $current_token->{Name};
        
        print "$current_state | $token_name \n";

        # if state_stack[-1] eq 'STMT' break

        my $action =
          $self->get_table_value( \%action_table, $current_state, $token_name );

        print Dumper(\@state_stack);
        
        if ( !$action ) {
            die "This action by ($current_state, $token_name) is not exists!";
            return;
        } 
        
        print Dumper(@$action), "\n\n";

        if ($action) {
            my ( $action_type, $action_state ) = @$action;
            
            if ( $action_type eq 'shift' ) {
                push @state_stack, $action_state;
                push @value_stack, $current_token;
                $pos++;
            }

            elsif ( $action_type eq 'reduce' ) {
                die "Ошибка: правило $action_state отсутствует!"
                  unless exists $rules{$action_state};

                my ( $lhs, $rhs_count ) = @{ $rules{$action_state} };
                my @children;

                # print "\nvalue_stack: ", Dumper( \@value_stack ), "\n";
                # print "rhs_count: ", "$rhs_count\n";

                for ( 1 .. $rhs_count ) {
                    pop @state_stack;
                    unshift @children, pop @value_stack;
                }

                if ( !exists $goto_table{ $state_stack[-1] }{$lhs} ) {
                    die "Ошибка: отсутствует переход в GOTO в состоянии $state_stack[-1] для $lhs";
                    return;
                }

                my $next_state = $goto_table{ $state_stack[-1] }{$lhs};
                push @state_stack, $next_state;

                my $node = { type => $lhs, children => \@children };
                push @value_stack, $node;
            }
            elsif ( $action_type eq 'accept' ) {
                print Dumper( \@value_stack );
                return \@value_stack;
            }
        }
        else {
            die "Ошибка парсинга: неожиданный токен '$current_token->{Text}' на строке $current_token->{Line}, колонке $current_token->{Column}\n";
        }
    }
}

1;



  # my %action_table = (

    #     # Начальное состояние 0: Ждем начало выражения
    #     0 => {
    #         # 'id'      => [ 'shift', 2 ],   # Если встречаем идентификатор (id), переходим в состояние 2
    #         'id'      => [ 'shift', 5 ], 
    #         'l_paren' => [ 'shift', 3 ]   # Если открывающая скобка, переходим в состояние 3
    #     },

    #     # Состояние 1: Завершенное выражение, ждем конец строки или файла
    #     1 => {
    #         'new_line' => [ 'reduce', 0 ],  # Конец строки - сворачиваем выражение
    #         'EOF'      => [ 'accept', 0 ]   # Конец файла - успешное завершение парсинга
    #     },

    #     # Состояние 2: После идентификатора (id), ожидаем оператор или конец выражения
    #     2 => {
    #         # 'plus'     => [ 'shift', 6 ],    # Если `+`, переходим в состояние 6
    #         # 'minus'    => [ 'shift', 6 ],    # Если `-`, переходим в состояние 6
    #         # 'multiply' => [ 'shift', 4 ],    # Если `*`, переходим в состояние 4
    #         # 'divide'   => [ 'shift', 4 ],    # Если `/`, переходим в состояние 4
    #         # 'r_paren'  => [ 'reduce', 3 ],   # Закрывающая скобка → свернуть `FACTOR → id`
    #         # 'EOF'      => [ 'reduce', 3 ]    # Если конец выражения, свернуть `FACTOR → id`
    #         'plus'     => [ 'reduce', 2 ],
    #         'multiply' => [ 'shift', 7 ],
    #         'divide'   => [ 'shift', 7 ],
    #         'r_paren'  => [ 'reduce', 2 ],
    #         'new_line' => [ 'reduce', 2 ],
    #     },

    #     # Состояние 3: После `(`, ждем новое выражение (вложенность)
    #     # 3 => {
    #     #     'id'      => [ 'shift', 2 ],    # Ждем идентификатор
    #     #     'l_paren' => [ 'shift', 3 ]     # Или новую вложенную скобку
    #     # },
        
    #     3 => {
    #         # 'plus' => [ 'reduce', 4 ],
    #         'divide'   => [ 'reduce', 2 ],
    #         'multiply' => [ 'reduce', 2 ],
    #         # 'r_paren' => [ 'reduce', 4 ],
    #         # 'new_line' => [ 'reduce', 4 ],
    #     },

    #     # Состояние 4: После `*` или `/`, ждем следующий идентификатор
    #     4 => {
    #         'id'      => [ 'shift', 5 ],    # Ожидаем число или переменную
    #         'l_paren' => [ 'shift', 3 ]     # Или новую скобку
    #     },

    #     # Состояние 5: Завершение `FACTOR`, проверяем следующий оператор
    #     5 => {
    #         'plus'     => [ 'reduce', 2 ],    # Завершаем `TERM * FACTOR` → `TERM`
    #         'minus'    => [ 'reduce', 2 ],    # Завершаем `TERM / FACTOR` → `TERM`
    #         # 'multiply' => [ 'shift',  4 ],    # Если еще одно `*`, продолжаем цепочку умножений
    #         'multiply' => [ 'reduce', 3 ],
    #         'divide'   => [ 'shift',  4 ],    # Если еще одно `/`, продолжаем цепочку делений
    #         'r_paren'  => [ 'reduce', 2 ],    # Закрывающая скобка → свернуть `TERM`
    #         'EOF'      => [ 'reduce', 2 ]     # Конец строки → свернуть `TERM`
    #     },

    #     # Состояние 6: После `+` или `-`, ждем `TERM`
    #     6 => {
    #         'id'      => [ 'shift', 2 ],    # Число или переменная после `+` или `-`
    #         'l_paren' => [ 'shift', 3 ]     # Или новая скобка
    #     },

    #     7 => {
    #         'id' => [ 'reduce', 3 ]     # Fact -> id
    #     },

    #     8 => {
    #         'id' => [ 'reduce', 2 ]     # Term -> Fact
    #     },

    #     9 => {
    #         'id' => [ 'reduce', 1 ]     # Expr -> Term
    #     },
    # );

    # my %rules = (
    #     # Базовые правила
    #     1 => [ 'EXPR', 1 ],    # EXPR → TERM
    #     2 => [ 'TERM', 1 ],    # TERM → FACTOR
    #     3 => [ 'FACTOR', 1 ],  # FACTOR → id
    #     4 => [ 'FACTOR', 3 ],  # FACTOR → ( EXPR )

    #     # Правила для сложения и вычитания (низкий приоритет)
    #     5 => [ 'EXPR', 2 ],    # EXPR → EXPR + TERM
    #     6 => [ 'EXPR', 2 ],    # EXPR → EXPR - TERM

    #     # Правила для умножения и деления (высокий приоритет)
    #     7 => [ 'TERM', 2 ],    # TERM → TERM * FACTOR
    #     8 => [ 'TERM', 2 ],    # TERM → TERM / FACTOR
    # );
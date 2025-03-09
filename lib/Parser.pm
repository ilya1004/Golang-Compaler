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

sub should_skip_punctuation {
    my ( $self, $token_name ) = @_;
    return  $token_name eq "semicolon";
            # $token_name eq "l_paren" ||
            # $token_name eq "r_paren";
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
        
        -1 => {     # EOF
            'EOF'       => [ 'accept', 0 ], 
            'semicolon' => [ 'accept', 0 ],
        },

        # package 
        0 => {
            'package' => [ 'shift', 1 ],
            # 'import'  => [ 'shift', 4 ],
            'func'    => [ 'shift', -1 ],
            # 'semicolon' => [ 'shift', -1 ],
        },

        1 => {
            'id'      => [ 'shift', 2 ],
        },

        2 => {
            'semicolon' => [ 'reduce', 1 ],
        },

        3 => {
            'semicolon' => [ 'shift', 2_0 ],
        },


        # import 
        2_0 => {
            'semicolon' => [ 'shift', 20 ],
            'import'    => [ 'shift',  2_1 ],
        },

        2_1 => {
            'l_paren' => [ 'shift', 2_2 ],
        },

        2_2 => {
            'string'  => [ 'shift', 2_3 ],
            'r_paren' => [ 'shift', 2_5 ],
        },

        2_3 => {
            'semicolon' => [ 'reduce', 4],
            'r_paren'   => [ 'reduce', 4],
        },

        2_4 => {
            'string'  => [ 'shift', 2_3],
            'r_paren' => [ 'reduce', 3]
        },

        2_5 => {
            'semicolon' => [ 'reduce', 2],
        },


        # 4 => {
        #     'string'  => [ '' ] 
        # }

        1_0 => {
            'id'       => [ 'shift', 1_5 ], 
            'l_paren'  => [ 'shift', 1_4 ],
        },

        1_1 => {
            'plus'     => [ 'shift',  1_6 ],
            # 'newline' => [ 'accept', 0 ],
            'EOF'      => [ 'accept', 0 ],  # add
        },

        1_2 => {
            'plus'     => [ 'reduce', 1_2 ],
            'minus'    => [ 'reduce', 1_2 ],  # add
            'multiply' => [ 'shift',  1_7 ],
            'divide'   => [ 'shift',  1_7 ],   # add
            'r_paren'  => [ 'reduce', 1_2 ],
            'newline' => [ 'reduce', 1_2 ],
        },

        1_3 => {
            'plus'     => [ 'reduce', 4 ],
            'minus'    => [ 'reduce', 4 ],  # add
            'multiply' => [ 'reduce', 4 ],
            'divide'   => [ 'reduce', 4 ],  # add
            'r_paren'  => [ 'reduce', 4 ],
            'newline' => [ 'reduce', 4 ],
            'EOF'      => [ 'reduce', 4 ],  # add
        },

        1_4 => {
            'id'      => [ 'shift', 15 ],
            'l_paren' => [ 'shift', 14 ],
        },

        1_5 => {
            'plus'     => [ 'reduce', 6 ],
            'minus'    => [ 'reduce', 6 ],  # add
            'multiply' => [ 'reduce', 6 ],
            'divide'   => [ 'reduce', 6 ],  # add
            'r_paren'  => [ 'reduce', 6 ],
            'newline' => [ 'reduce', 6 ],
            'EOF'      => [ 'reduce', 6 ],  # add
        },

        1_6 => {
            'id'       => [ 'shift', 15 ],
            'l_paren'  => [ 'shift', 14 ],
        },

        1_7 => {
            'id'       => [ 'shift', 1_5 ],
            'l_paren'  => [ 'shift', 1_4 ],
        },

        1_8 => {
            'plus'     => [ 'shift', 1_6  ],
            'minus'    => [ 'shift', 1_6  ],   # add
            'r_paren'  => [ 'shift', 1_11 ],
        },

        1_9 => {
            'plus'     => [ 'reduce', 1_1 ],
            'minus'    => [ 'reduce', 1_1 ],  # add
            'multiply' => [ 'shift',  1_7 ],
            'divide'   => [ 'shift',  1_7 ],  # add
            'r_paren'  => [ 'reduce', 1_1 ],
            'newline' => [ 'reduce', 1_1 ],
            'EOF'      => [ 'reduce', 1_1 ],  # add
        },

        1_10 => {
            'plus'     => [ 'reduce', 1_3 ],
            'minus'    => [ 'reduce', 1_3 ],  # add
            'multiply' => [ 'shift',  1_3 ],
            'divide'   => [ 'shift',  1_3 ],  # add
            'r_paren'  => [ 'reduce', 1_3 ],
            'newline' => [ 'reduce', 1_3 ],
            'EOF'      => [ 'reduce', 1_3 ],  # add
        },

        1_11 => {
            'plus'     => [ 'reduce', 1_5 ],
            'minus'    => [ 'reduce', 1_5 ],  # add
            'multiply' => [ 'shift',  1_5 ],
            'divide'   => [ 'shift',  1_5 ],  # add
            'r_paren'  => [ 'reduce', 1_5 ],
            'newline'  => [ 'reduce', 1_5 ],
            'EOF'      => [ 'reduce', 1_5 ],  # add
        },

    );

    # Выбран reduce

    # $rules{action_state} = [ lhs, rhs_count ];
    # actions_state — текущее состояние (номер правила).
    # lhs — нетерминал, который получается после свертки.
    # rhs_count — сколько элементов убрать из value_stack.
    my %rules = (
        1   => [ 'PACKAGE', 2 ], # PACKAGE → package id
        # 2   => [ 'IMPORT_DECL', 2 ], # IMPORT_DECL -> 'import' string_lit
        
        2   => [ 'IMPORT_DECL',  4 ],  # import_decl → import ( import_specs )
        3   => [ 'IMPORT_SPECS', 3 ],  # import_specs → import_specs semicolon import_str
        4   => [ 'IMPORT_SPECS', 1 ],  # import_specs → import_str

        1_1 => [ 'EXPR', 3 ],    # EXPR → EXPR +/- TERM
        1_2 => [ 'EXPR', 1 ],    # EXPR → TERM 
        1_3 => [ 'TERM', 3 ],    # TERM → TERM *|/ FACTOR
        1_4 => [ 'TERM', 1 ],    # TERM → FACTOR
        1_5 => [ 'FACTOR', 3 ],  # FACTOR → ( EXPR )
        1_6 => [ 'FACTOR', 1 ],  # FACTOR → id

    );

    # $goto_table{state}{nonterminal} = new_state;
    # state — текущее состояние автомата.
    # nonterminal — нетерминал, полученный после reduce.
    # new_state — состояние, в которое нужно перейти.
    my %goto_table = (
        0 => {
            'PACKAGE' => 2_0,
        },

        # 3 => {
        #     'IMPORT' => ,
        # },

        2_0 => {
            'IMPORT_DECL' => -1,
        },

        # 2_1 => {
        #     'IMPORT_SPECS' => 
        # },

        2_2 => {
            "IMPORT_SPECS" => 2_2,
        },


        1_0 => {
            'EXPR'   => 1_1,
            'TERM'   => 1_2,
            'FACTOR' => 1_3,
        },

        1_2 => {
            'TERM'   => 1_2,
        },

        1_4 => { 
            'EXPR'   => 1_8,
            'TERM'   => 1_2,
            'FACTOR' => 1_3, 
        },

        1_6 => { 
            'TERM'   => 1_9,
            'FACTOR' => 1_3,
        },
        1_7 => { 
            'FACTOR' => 1_10,
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
        
        print "Selected action:\n", Dumper(@$action);

        if ($action) {
            my ( $action_type, $action_state ) = @$action;
            
            if ( $action_type eq 'shift' ) {  
                push @state_stack, $action_state;
                if ( ! $self->should_skip_punctuation($token_name)) {
                    push @value_stack, $current_token;
                }
                $pos++;
            }

            elsif ( $action_type eq 'reduce' ) {
                die "Ошибка: правило $action_state отсутствует!"
                  unless exists $rules{$action_state};

                my ( $lhs, $rhs_count ) = @{ $rules{$action_state} };
                my @children;

                # print "\nvalue_stack: ", Dumper( \@value_stack ), "\n";
                print "Deleted from stack count: ", "$rhs_count\n";

                for ( 1 .. $rhs_count ) {
                    pop @state_stack;
                    unshift @children, pop @value_stack;
                }

                if ( !exists $goto_table{ $state_stack[-1] }{$lhs} ) {
                    die "Ошибка: отсутствует переход GOTO ( $state_stack[-1] | $lhs )";
                    return;
                }

                print "GOTO ( $state_stack[-1] | $lhs )\n";
                
                my $next_state = $goto_table{ $state_stack[-1] }{$lhs};
                push @state_stack, $next_state;

                print "Next state: $next_state \n";

                # Фильтруем children, удаляя ненужные токены
                my %exclude_names = (
                    'l_paren' => 1,
                    'r_paren' => 1,
                );
                @children = @{ filter_children(\@children, \%exclude_names) };

                my $node = { type => $lhs, children => \@children };
                
                push @value_stack, $node;
                if ($current_token->{Name} eq "semicolon") {
                    $pos++;
                }
            }
            elsif ( $action_type eq 'accept' ) {
                # print Dumper( \@value_stack );
                return \@value_stack;
            }
        }
        else {
            die "Ошибка парсинга: неожиданный токен '$current_token->{Text}' на строке $current_token->{Line}, колонке $current_token->{Column}\n";
        }
        print "\n\n";
    }
}

sub filter_children {
    my ($children, $exclude_names) = @_;
    return [ grep { !exists $exclude_names->{$_->{Name}} } @$children ];
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
    #         'newline' => [ 'reduce', 0 ],  # Конец строки - сворачиваем выражение
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
    #         'newline' => [ 'reduce', 2 ],
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
    #         # 'newline' => [ 'reduce', 4 ],
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
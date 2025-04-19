package SemanticAnalyzer;

use strict;
use warnings;
use Data::Dumper;
use JSON;

sub new {
    my ($class, $cst, $symbol_table, $imports) = @_;
    my $self = {
        cst          => $cst,
        symbol_table => $symbol_table,
        imports      => $imports,
        errors       => [],
        current_scope => '-Global-',
        processed_nodes => {},
    };
    bless $self, $class;
    return $self;
}

# Main method to start analysis
sub analyze {
    my ($self) = @_;
    $self->traverse_cst($self->{cst});
    # Сохраняем обновленную таблицу символов
    $self->save_symbol_table();
    return $self->{errors};
}

# Save symbol table to file
sub save_symbol_table {
    my ($self) = @_;
    my $output_dir = 'results';
    my $symbol_table_filename = "$output_dir/res_symbol_table_updated.json";
    
    my $symbol_table_json = to_json($self->{symbol_table}, {
        pretty => 1,
        canonical => 1,
    });
    
    open(my $fh, '>', $symbol_table_filename) or die "Не удалось открыть файл '$symbol_table_filename' для записи: $!";
    print $fh $symbol_table_json;
    close($fh);
    
    print "Обновленная таблица символов записана в файл '$symbol_table_filename'.\n";
}

# Recursive traversal of CST
sub traverse_cst {
    my ($self, $node) = @_;
    print "traverse_cst\n";
    if (ref($node) eq 'ARRAY') {
        foreach my $child (@$node) {
            $self->traverse_cst($child);
        }
    } elsif (ref($node) eq 'HASH') {
        my $node_id = "$node";
        return if $self->{processed_nodes}->{$node_id};
        $self->{processed_nodes}->{$node_id} = 1;

        $self->analyze_node($node);
        foreach my $key (keys %$node) {
            next if exists $node->{type} && $node->{type} eq 'Expression' && $key eq 'value';
            $self->traverse_cst($node->{$key}) if ref($node->{$key});
        }
    }
}

# Analyze a specific node
sub analyze_node {
    my ($self, $node) = @_;
    print "analyze_node\n";
    return unless exists $node->{type};
    my $type = $node->{type};

    if ($type eq 'BinaryOperation') {
        $self->check_binary_operation($node);
    } elsif ($type eq 'VariableDeclaration' || $type eq 'ShortVariableDeclaration') {
        $self->check_declaration($node);
    } elsif ($type eq 'CallExpression') {
        $self->check_call_expression($node);
    } elsif ($type eq 'FunctionDeclaration') {
        $self->enter_scope($node->{name});
        $self->traverse_cst($node->{body});
        $self->exit_scope();
    } elsif ($type eq 'Expression') {
        if (exists $node->{value} && ref($node->{value}) eq 'HASH') {
            my $value_node_id = "$node->{value}";
            $self->{processed_nodes}->{$value_node_id} = 1;
            $self->analyze_node($node->{value});
        }
    } elsif ($type eq 'Program' || $type eq 'PackageDeclaration') {
        # Обходим дочерние узлы для Program и PackageDeclaration
        if (exists $node->{children}) {
            $self->traverse_cst($node->{children});
        } elsif (exists $node->{nodes}) {
            $self->traverse_cst($node->{nodes});
        }
    }
}

# Enter a new scope
sub enter_scope {
    my ($self, $scope_name) = @_;
    print "enter_scope\n";
    $self->{current_scope} = $scope_name;
}

# Exit the current scope
sub exit_scope {
    my ($self) = @_;
    $self->{current_scope} = '-Global-';
}

# Translate type names to Russian
sub translate_type {
    my ($self, $type) = @_;
    print "translate_type\n";
    print "--------------------------------------------------------\n";
    print Dumper($type), "\n";
    my %type_translations = (
        'int'      => 'целочисленный',
        'int8'     => 'целочисленный (8 бит)',
        'int16'    => 'целочисленный (16 бит)',
        'int32'    => 'целочисленный (32 бита)',
        'int64'    => 'целочисленный (64 бита)',
        'uint'     => 'беззнаковый целочисленный',
        'uint8'    => 'беззнаковый целочисленный (8 бит)',
        'uint16'   => 'беззнаковый целочисленный (16 бит)',
        'uint32'   => 'беззнаковый целочисленный (32 бита)',
        'uint64'   => 'беззнаковый целочисленный (64 бита)',
        'float32'  => 'число с плавающей точкой (32 бита)',
        'float64'  => 'число с плавающей точкой (64 бита)',
        'string'   => 'строка',
        'bool'     => 'логический',
        'unknown'  => 'неизвестный',
        'auto'     => 'автоматический'
    );
    return $type_translations{$type} || $type;
}

# Check binary operations
sub check_binary_operation {
    my ($self, $node) = @_;
    print "check_binary_operation\n";
    unless (exists $node->{left} && exists $node->{right} && exists $node->{operator}) {
        $self->add_error("Некорректная структура бинарной операции", $node->{Pos} || 0);
        return;
    }

    my $left_type  = $self->get_type($node->{left});
    my $right_type = $self->get_type($node->{right});
    my $operator   = $node->{operator}{value};

    if ($left_type eq 'unknown' || $right_type eq 'unknown') {
        $self->add_error("Неизвестный тип в бинарной операции", $node->{operator}{Pos});
        return;
    }

    if ($left_type ne $right_type) {
        $self->add_error("Несовместимые типы: " . $self->translate_type($left_type) . " и " . $self->translate_type($right_type) . " для оператора $operator", $node->{operator}{Pos});
        return;
    }

    if ($operator eq '+' && $left_type !~ /^(int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|string)$/) {
        $self->add_error("Оператор + применим только к целочисленным, числам с плавающей точкой или строкам, получен " . $self->translate_type($left_type), $node->{operator}{Pos});
    } elsif ($operator =~ /^(-|\*|\/)$/ && $left_type !~ /^(int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64)$/) {
        $self->add_error("Оператор $operator применим только к целочисленным или числам с плавающей точкой, получен " . $self->translate_type($left_type), $node->{operator}{Pos});
    } elsif ($operator =~ /^(<|>|<=|>=|==|!=)$/ && $left_type !~ /^(int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|string|bool)$/) {
        $self->add_error("Оператор $operator применим только к целочисленным, числам с плавающей точкой, строкам или логическим значениям, получен " . $self->translate_type($left_type), $node->{operator}{Pos});
    } elsif ($operator =~ /^(&&\|\|)$/ && $left_type ne 'bool') {
        $self->add_error("Оператор $operator применим только к логическим значениям, получен " . $self->translate_type($left_type), $node->{operator}{Pos});
    }
}

# Check variable declarations
sub check_declaration {
    my ($self, $node) = @_;
    print "check_declaration\n";
    print Dumper($node), "\n";

    # Проверяем, что узел имеет тип VariableDeclaration или ShortVariableDeclaration и содержит массив nodes
    unless (($node->{type} eq 'VariableDeclaration' || $node->{type} eq 'ShortVariableDeclaration') && 
            exists $node->{nodes} && ref($node->{nodes}) eq 'ARRAY') {
        $self->add_error("Некорректная структура декларации переменной", $node->{Pos} || 0);
        return;
    }

    my $nodes = $node->{nodes};
    my $is_var_declaration = ($node->{type} eq 'VariableDeclaration');
    my ($identifier, $declared_type, $expression, $var_pos);

    if ($is_var_declaration) {
        unless (scalar(@{$nodes}) >= 5 && $nodes->[0]{Name} eq 'var') {
            $self->add_error("Некорректная структура декларации переменной с var", $node->{Pos} || 0);
            return;
        }
        $identifier = $nodes->[1];  # Идентификатор (например, a)
        $declared_type = $nodes->[2];  # Явный тип (например, int)
        $expression = $nodes->[4];  # Выражение
        $var_pos = $identifier->{Pos} || $node->{Pos} || 0;

        # Проверяем идентификатор
        unless ($identifier->{Name} =~ /^id-/ && exists $identifier->{Text}) {
            $self->add_error("Ожидается идентификатор в декларации var", $var_pos);
            return;
        }
        # Проверяем явный тип
        unless ($declared_type->{Name} eq 'Type' && exists $declared_type->{Text}) {
            $self->add_error("Ожидается тип в декларации var", $declared_type->{Pos} || $node->{Pos} || 0);
            return;
        }
    } else {
        unless (scalar(@{$nodes}) >= 3 && $nodes->[1]{Name} eq 'declaration' && $nodes->[1]{Text} eq ':=') {
            $self->add_error("Некорректная структура короткой декларации переменной", $node->{Pos} || 0);
            return;
        }
        $identifier = $nodes->[0];  # Идентификатор (например, y)
        $expression = $nodes->[2];  # Выражение
        $var_pos = $identifier->{Pos} || $node->{Pos} || 0;

        # Проверяем идентификатор
        unless ($identifier->{Name} =~ /^id-/ && exists $identifier->{Text}) {
            $self->add_error("Ожидается идентификатор в короткой декларации", $var_pos);
            return;
        }
    }

    # Проверяем, что выражение корректно
    unless ($expression->{type} eq 'Expression' && exists $expression->{value}) {
        $self->add_error("Правая часть декларации должна быть выражением", $expression->{Pos} || $node->{Pos} || 0);
        return;
    }

    my $var_name = $identifier->{Text};
    my $var_type = $self->get_variable_type($var_name);
    my $right_type = $self->get_type($expression->{value});
    my $declared_type_value = $is_var_declaration ? $declared_type->{Text} : 'auto';

    print "------------------------\n";
    print "Right type: $right_type\n";
    print "Variable type: $var_type\n";
    print "Declared type: $declared_type_value\n";
    print Dumper($identifier), "\n";

    if ($var_type eq 'unknown') {
        $self->add_error("Переменная $var_name не объявлена в таблице символов", $var_pos);
        return;
    }

    if ($right_type eq 'unknown') {
        $self->add_error("Неизвестный тип в правой части декларации", $identifier->{value}{Pos} || $identifier->{Pos} || $node->{Pos} || 0);
        return;
    }

    # Для var-декларации с явным типом проверяем соответствие
    if ($is_var_declaration && $declared_type_value ne 'auto') {
        if ($declared_type_value ne $right_type) {
            $self->add_error(
                "Несовместимые типы: нельзя присвоить " . $self->translate_type($right_type) . 
                " переменной типа " . $self->translate_type($declared_type_value), 
                $expression->{value}{Pos} || $expression->{Pos} || $node->{Pos} || 0
            );
            return;
        }
    }

    # Для бинарных операций проверяем совместимость типов операндов
    if ($expression->{value}{type} eq 'BinaryOperation') {
        my $left_type = $self->get_type($expression->{value}{left});
        my $right_operand_type = $self->get_type($expression->{value}{right});
        my $operator = $expression->{value}{operator}{value};

        # Проверяем допустимые комбинации типов для арифметических операций
        if ($operator =~ /^(\+|-|\*|\/)$/) {
            if ($left_type eq 'float64' || $right_operand_type eq 'float64') {
                # Если хотя бы один операнд float64, результат float64
                unless ($right_type eq 'float64') {
                    $self->add_error(
                        "Ожидается тип float64 для результата бинарной операции с float64", 
                        $expression->{value}{Pos} || $node->{Pos} || 0
                    );
                    return;
                }
            } elsif ($left_type eq 'int' && $right_operand_type eq 'int') {
                # Если оба операнда int, результат int
                unless ($right_type eq 'int') {
                    $self->add_error(
                        "Ожидается тип int для результата бинарной операции между int", 
                        $expression->{value}{Pos} || $node->{Pos} || 0
                    );
                    return;
                }
            } else {
                $self->add_error(
                    "Несовместимые типы в бинарной операции: $left_type и $right_operand_type", 
                    $expression->{value}{Pos} || $node->{Pos} || 0
                );
                return;
            }
        }
    }

    # Обновляем таблицу символов, если тип auto (для var или :=)
    if ($var_type eq 'auto') {
        print "==============\n";
        my $scope = $self->{current_scope};
        my $new_type = $is_var_declaration && $declared_type_value ne 'auto' ? $declared_type_value : $right_type;
        if (exists $self->{symbol_table}{scopes}{$scope}{variables}{$var_name}) {
            $self->{symbol_table}{scopes}{$scope}{variables}{$var_name}{type} = $new_type;
        } elsif (exists $self->{symbol_table}{scopes}{"-Global-"}{variables}{$var_name}) {
            $self->{symbol_table}{scopes}{"-Global-"}{variables}{$var_name}{type} = $new_type;
        }
        print Dumper($self->{symbol_table}{scopes}{$scope}{variables}), "\n";
    }

    # Проверка совместимости типов, если переменная не auto
    if ($var_type ne 'auto' && $var_type ne $right_type) {
        $self->add_error(
            "Несовместимые типы: нельзя присвоить " . $self->translate_type($right_type) . 
            " переменной типа " . $self->translate_type($var_type), 
            $expression->{value}{Pos} || $expression->{Pos} || $node->{Pos} || 0
        );
    }
}

# Check function calls
sub check_call_expression {
    my ($self, $node) = @_;
    print "check_call_expression\n";
    my $func_name = $node->{callee}{value};
    my $args = $node->{arguments};

    my $func_info = $self->{symbol_table}{scopes}{"-Global-"}{functions}{$func_name};
    if (!defined $func_info) {
        $self->add_error("Функция $func_name не объявлена", $node->{callee}{Pos});
        return;
    }

    my @param_types = @{$func_info->{parameters}};
    if (scalar(@param_types) != scalar(@$args)) {
        $self->add_error("Неверное количество аргументов для функции $func_name", $node->{Pos});
        return;
    }

    for my $i (0 .. $#param_types) {
        my $arg_type = $self->get_type($args->[$i]);
        if ($arg_type ne $param_types[$i]) {
            $self->add_error("Несовместимый тип аргумента $i: ожидается " . $self->translate_type($param_types[$i]) . ", получен " . $self->translate_type($arg_type), $args->[$i]{Pos});
        }
    }
}

# Get the type of an expression
sub get_type {
    my ($self, $expr) = @_;
    print "get_type\n";
    return 'unknown' unless ref($expr) eq 'HASH';

    my $type = $expr->{type} || '';
    if ($type eq 'Identifier') {
        return $self->get_variable_type($expr->{value});
    } elsif ($type eq 'StringLiteral') {
        return 'string';
    } elsif ($type eq 'BoolLiteral') {
        return 'bool';
    } elsif ($type eq 'IntLiteral') {
        return 'int';
    } elsif ($type eq 'FloatLiteral') {
        return 'float64';
    } elsif ($type eq 'Expression' && exists $expr->{value}) {
        return $self->get_type($expr->{value});
    } elsif ($type eq 'BinaryOperation') {
        my $left_type = $self->get_type($expr->{left});
        my $right_type = $self->get_type($expr->{right});
        if ($left_type eq $right_type && $left_type ne 'unknown') {
            my $operator = $expr->{operator}{value};
            return 'bool' if $operator =~ /^(==|!=|<|>|<=|>=)$/ && $left_type =~ /^(int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|string|bool)$/;
            return 'bool' if $operator =~ /^(&&\|\|)$/ && $left_type eq 'bool';
            return $left_type if $operator =~ /^(\+|-|\*|\/)$/ && $left_type =~ /^(int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|string)$/;
        }
        return 'unknown';
    }
    return 'unknown';
}

# Get the type of a variable from the symbol table
sub get_variable_type {
    my ($self, $var_name) = @_;
    print "get_variable_type\n";
    my $scope = $self->{current_scope};
    if (exists $self->{symbol_table}{scopes}{$scope}{variables}{$var_name}) {
        my $var_info = $self->{symbol_table}{scopes}{$scope}{variables}{$var_name};
        if ($var_info->{type} eq 'auto' && exists $var_info->{value}) {
            # return $self->get_type($var_info->{value});
            return "auto"
        }
        return $var_info->{type};
    } elsif (exists $self->{symbol_table}{scopes}{"-Global-"}{variables}{$var_name}) {
        my $var_info = $self->{symbol_table}{scopes}{"-Global-"}{variables}{$var_name};
        if ($var_info->{type} eq 'auto' && exists $var_info->{value}) {
            # return $self->get_type($var_info->{value});
            return "auto"
        }
        return $var_info->{type};
    }
    return 'unknown';
}

# Add an error
sub add_error {
    my ($self, $message, $pos) = @_;
    push @{$self->{errors}}, { message => $message, pos => $pos };
}

1;
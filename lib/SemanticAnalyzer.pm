package SemanticAnalyzer;

use strict;
use warnings;
use Data::Dumper;
use JSON;

use BuiltInFunctions;

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

# Save symbol table to file
sub save_symbol_table {
    my ($self) = @_;
    my $output_dir = 'results';
    my $symbol_table_filename = "$output_dir/res_symbol_table_updated.json";
    # print Dumper($self->{symbol_table}{scopes}{"generateSequence"});
    my $symbol_table_json = to_json($self->{symbol_table}, {
        pretty => 1,
        canonical => 1,
    });
    
    open(my $fh, '>', $symbol_table_filename) or die "Не удалось открыть файл '$symbol_table_filename' для записи: $!";
    print $fh $symbol_table_json;
    close($fh);
    
    print "Обновленная таблица символов записана в файл '$symbol_table_filename'.\n";
}

# Main method to start analysis
sub analyze {
    my ($self) = @_;
    $self->traverse_cst($self->{cst});
    $self->save_symbol_table();
    return $self->{errors};
}

# Recursive traversal of CST
sub traverse_cst {
    my ($self, $node) = @_;
    # print "traverse_cst\n";
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
    return unless exists $node->{type};
    my $type = $node->{type};

    if ($type eq 'BinaryOperation') {
        $self->check_binary_operation($node);
    } elsif ($type eq 'VariableDeclaration' || $type eq 'ShortVariableDeclaration') {
        $self->check_declaration($node);
    } elsif ($type eq 'ConstDeclaration') {
        $self->check_const_declaration($node);
    } elsif ($type eq 'FunctionCall') {
        $self->check_function_call($node);
    } elsif ($type eq 'FunctionDeclaration') {
        $self->enter_scope($node->{name});
        $self->traverse_cst($node->{body});
        $self->exit_scope();
    } elsif ($type eq 'ForLoop') {
        $self->check_for_loop($node);
    } elsif ($type eq 'Expression') {
        if (exists $node->{value} && ref($node->{value}) eq 'HASH') {
            my $value_node_id = "$node->{value}";
            $self->{processed_nodes}->{$value_node_id} = 1;
            $self->analyze_node($node->{value});
        }
    } elsif ($type eq 'Program' || $type eq 'PackageDeclaration') {
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

# Get the type of an expression
sub get_type {
    my ($self, $expr) = @_;
    if (ref($expr) ne 'HASH' || !exists $expr->{type}) {
        return 'unknown';
    }

    my $type = $expr->{type} || $expr->{Name} || '';
    if ($type eq 'Type' && exists $expr->{Text}) {
        return $expr->{Text};
    } elsif ($type eq 'Identifier') {
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
    } elsif ($type eq 'FieldAccess') {
        my $object_name = $expr->{object}{value};
        my $field_name = $expr->{field}{value};
        my $object_type = $self->get_variable_type($object_name);

        unless ($object_type && $object_type ne 'unknown') {
            $self->add_error(
                "Объект '$object_name' не определен или имеет неизвестный тип",
                $expr->{object}{Pos} || $expr->{Pos} || 0
            );
            return 'unknown';
        }

        unless (exists $self->{symbol_table}{types}{$object_type}) {
            $self->add_error(
                "Тип '$object_type' объекта '$object_name' не является структурой",
                $expr->{object}{Pos} || $expr->{Pos} || 0
            );
            return 'unknown';
        }

        my $struct_fields = $self->{symbol_table}{types}{$object_type}{fields};
        unless ($field_name && exists $struct_fields->{$field_name}) {
            $self->add_error(
                "Поле '$field_name' не определено в структуре '$object_type'",
                $expr->{field}{Pos} || $expr->{Pos} || 0
            );
            return 'unknown';
        }

        return $struct_fields->{$field_name};
    }

    return 'unknown';
}

# Get the type of a variable from the symbol table
sub get_variable_type {
    my ($self, $var_name, $usage_pos) = @_;
    my $scope = $self->{current_scope} || '-Global-';

    # Проверяем текущую область (переменные и константы)
    if (exists $self->{symbol_table}{scopes}{$scope}{variables}{$var_name}) {
        my $var_info = $self->{symbol_table}{scopes}{$scope}{variables}{$var_name};
        # Если usage_pos не передан, возвращаем тип без проверки позиции
        if (!defined($usage_pos)) {
            return $var_info->{type} eq 'auto' && exists $var_info->{value} ? 'auto' : $var_info->{type};
        }
        # Проверяем, что позиция декларации меньше или равна позиции использования
        if ($usage_pos >= $var_info->{pos}) {
            return $var_info->{type} eq 'auto' && exists $var_info->{value} ? 'auto' : $var_info->{type};
        }
    }
    if (exists $self->{symbol_table}{scopes}{$scope}{constants}{$var_name}) {
        my $const_info = $self->{symbol_table}{scopes}{$scope}{constants}{$var_name};
        if (!defined($usage_pos)) {
            return $const_info->{type};
        }
        if ($usage_pos >= $const_info->{pos}) {
            return $const_info->{type};
        }
    }

    # Проверяем inner_scopes текущей области
    if (exists $self->{symbol_table}{scopes}{$scope}{inner_scopes}) {
        for my $inner_scope (@{$self->{symbol_table}{scopes}{$scope}{inner_scopes}}) {
            if (exists $inner_scope->{variables}{$var_name}) {
                my $var_info = $inner_scope->{variables}{$var_name};
                if (!defined($usage_pos)) {
                    return $var_info->{type} eq 'auto' && exists $var_info->{value} ? 'auto' : $var_info->{type};
                }
                if ($usage_pos >= $var_info->{pos}) {
                    return $var_info->{type} eq 'auto' && exists $var_info->{value} ? 'auto' : $var_info->{type};
                }
            }
            if (exists $inner_scope->{constants}{$var_name}) {
                my $const_info = $inner_scope->{constants}{$var_name};
                if (!defined($usage_pos)) {
                    return $const_info->{type};
                }
                if ($usage_pos >= $const_info->{pos}) {
                    return $const_info->{type};
                }
            }
        }
    }

    # Проверяем родительские области
    my @scope_parts = split('_', $scope);
    while (@scope_parts) {
        pop @scope_parts;
        my $parent_scope = @scope_parts ? join('_', @scope_parts) : '-Global-';
        if (exists $self->{symbol_table}{scopes}{$parent_scope}{variables}{$var_name}) {
            my $var_info = $self->{symbol_table}{scopes}{$parent_scope}{variables}{$var_name};
            if (!defined($usage_pos)) {
                return $var_info->{type} eq 'auto' && exists $var_info->{value} ? 'auto' : $var_info->{type};
            }
            if ($usage_pos >= $var_info->{pos}) {
                return $var_info->{type} eq 'auto' && exists $var_info->{value} ? 'auto' : $var_info->{type};
            }
        }
        if (exists $self->{symbol_table}{scopes}{$parent_scope}{constants}{$var_name}) {
            my $const_info = $self->{symbol_table}{scopes}{$parent_scope}{constants}{$var_name};
            if (!defined($usage_pos)) {
                return $const_info->{type};
            }
            if ($usage_pos >= $const_info->{pos}) {
                return $const_info->{type};
            }
        }
        # Проверяем inner_scopes родительской области
        if (exists $self->{symbol_table}{scopes}{$parent_scope}{inner_scopes}) {
            for my $inner_scope (@{$self->{symbol_table}{scopes}{$parent_scope}{inner_scopes}}) {
                if (exists $inner_scope->{variables}{$var_name}) {
                    my $var_info = $inner_scope->{variables}{$var_name};
                    if (!defined($usage_pos)) {
                        return $var_info->{type} eq 'auto' && exists $var_info->{value} ? 'auto' : $var_info->{type};
                    }
                    if ($usage_pos >= $var_info->{pos}) {
                        return $var_info->{type} eq 'auto' && exists $var_info->{value} ? 'auto' : $var_info->{type};
                    }
                }
                if (exists $inner_scope->{constants}{$var_name}) {
                    my $const_info = $inner_scope->{constants}{$var_name};
                    if (!defined($usage_pos)) {
                        return $const_info->{type};
                    }
                    if ($usage_pos >= $const_info->{pos}) {
                        return $const_info->{type};
                    }
                }
            }
        }
        last if $parent_scope eq '-Global-';
    }

    return 'unknown';
}

# Add an error
sub add_error {
    my ($self, $message, $pos) = @_;
    push @{$self->{errors}}, { message => $message, pos => $pos };
}

# Check variable declarations
sub check_declaration {
    my ($self, $node) = @_;
    unless (($node->{type} eq 'VariableDeclaration' || $node->{type} eq 'ShortVariableDeclaration') && 
            exists $node->{nodes} && ref($node->{nodes}) eq 'ARRAY') {
        $self->add_error("Некорректная структура декларации переменной", $node->{Pos} || 0);
        return;
    }

    my $nodes = $node->{nodes};
    my $is_var_declaration = ($node->{type} eq 'VariableDeclaration');
    my $scope = $self->{current_scope} || '-Global-';

    if ($is_var_declaration) {
        unless (scalar(@{$nodes}) >= 3 && $nodes->[0]{Name} eq 'var') {
            $self->add_error("Некорректная структура декларации переменной с var", $node->{Pos} || 0);
            return;
        }

        my @identifiers;
        my $i = 1;
        while ($i < @$nodes && $nodes->[$i]{Name} =~ /^id-/ && exists $nodes->[$i]{Text}) {
            push @identifiers, $nodes->[$i];
            $i++;
            if ($i < @$nodes && $nodes->[$i]{Name} eq 'comma') {
                $i++;
            } else {
                last;
            }
        }

        unless (@identifiers) {
            $self->add_error("Ожидается хотя бы один идентификатор в декларации var", $nodes->[1]{Pos} || $node->{Pos} || 0);
            return;
        }

        # Проверяем, есть ли тип (например, 'float64', 'auto') или выражение
        my $has_type = ($i < @$nodes && $nodes->[$i]{Name} eq 'Type' && exists $nodes->[$i]{Text});
        my $declared_type = $has_type ? $nodes->[$i] : undef;
        my $declared_type_value = $declared_type ? $declared_type->{Text} : undef;

        # Проверяем наличие выражения ('=')
        my $has_expression = ($has_type ? $i + 1 : $i) < @$nodes && $nodes->[$has_type ? $i + 1 : $i]{Name} eq 'assignment';

        if (!$has_expression && !$has_type) {
            $self->add_error("Ожидается тип или выражение в декларации var", $nodes->[$i]{Pos} || $node->{Pos} || 0);
            return;
        }

        for my $identifier (@identifiers) {
            my $var_name = $identifier->{Text};
            my $var_pos = $identifier->{Pos} || $node->{Pos} || 0;
            if (exists $self->{symbol_table}{scopes}{$scope}{constants}{$var_name}) {
                $self->add_error("Идентификатор '$var_name' уже используется как константа в области '$scope'", $var_pos);
                return;
            }
            if (exists $self->{symbol_table}{functions}{$var_name}) {
                $self->add_error("Идентификатор '$var_name' уже используется как имя функции", $var_pos);
                return;
            }
        }

        if ($has_expression) {
            my $expr_index = $has_type ? $i + 2 : $i + 1;
            unless ($expr_index < @$nodes) {
                $self->add_error("Ожидается выражение после '=' в декларации var", $nodes->[$expr_index - 1]{Pos} || $node->{Pos} || 0);
                return;
            }
            my $expression = $nodes->[$expr_index];
            my $right_type;

            # Проверяем, является ли выражение FunctionCall
            if (exists $expression->{type} && $expression->{type} eq 'Expression' && exists $expression->{value} &&
                exists $expression->{value}{type} && $expression->{value}{type} eq 'FunctionCall') {
                my $func_call = $expression->{value};
                if (exists $func_call->{return_type}) {
                    $right_type = $func_call->{return_type};
                } elsif (exists $func_call->{name} && exists $self->{symbol_table}{functions}{$func_call->{name}}) {
                    $right_type = $self->{symbol_table}{functions}{$func_call->{name}}{return_types}[0] || 'unknown';
                } else {
                    $right_type = 'unknown';
                }
            } else {
                # Иначе используем get_expression_type
                $right_type = $self->get_expression_type($expression->{type} eq 'Expression' ? $expression->{value} : $expression);
            }

            if ($right_type eq 'unknown' || ($right_type eq 'auto' && $declared_type_value ne 'auto')) {
                $self->add_error("Неизвестный или неподдерживаемый тип в правой части декларации var", $expression->{Pos} || $node->{Pos} || 0);
                return;
            }

            # Проверяем совместимость типов, если тип явно указан
            if ($has_type && $declared_type_value ne 'auto' && $declared_type_value ne $right_type) {
                for my $identifier (@identifiers) {
                    my $var_name = $identifier->{Text};
                    $self->add_error(
                        "Несовместимый тип в декларации переменной '$var_name': ожидался $declared_type_value, получен $right_type",
                        $expression->{Pos} || $node->{Pos} || 0
                    );
                }
                return;
            }

            # Если тип в CST — 'auto' или не указан, используем выведенный тип из выражения
            my $final_type = ($declared_type_value && $declared_type_value eq 'auto') || !$has_type ? $right_type : $declared_type_value;

            for my $identifier (@identifiers) {
                my $var_name = $identifier->{Text};
                my $var_pos = $identifier->{Pos} || $node->{Pos} || 0;
                $self->{symbol_table}{scopes}{$scope}{variables}{$var_name} = {
                    type => $final_type,
                    pos => $var_pos,
                    value => $expression
                };
            }
        } else {
            if ($declared_type_value eq 'auto') {
                $self->add_error("Тип 'auto' недопустим в декларации var без выражения", $declared_type->{Pos} || $node->{Pos} || 0);
                return;
            }
            for my $identifier (@identifiers) {
                my $var_name = $identifier->{Text};
                my $var_pos = $identifier->{Pos} || $node->{Pos} || 0;
                $self->{symbol_table}{scopes}{$scope}{variables}{$var_name} = {
                    type => $declared_type_value,
                    pos => $var_pos
                };
            }
        }
    } else {
        unless (scalar(@{$nodes}) >= 3 && $nodes->[1]{Name} eq 'declaration' && $nodes->[1]{Text} eq ':=') {
            $self->add_error("Некорректная структура короткой декларации переменной", $node->{Pos} || 0);
            return;
        }

        my $identifier = $nodes->[0];
        my $expression = $nodes->[2];
        my $var_pos = $identifier->{Pos} || $node->{Pos} || 0;

        unless ($identifier->{Name} =~ /^id-/ && exists $identifier->{Text}) {
            $self->add_error("Ожидается идентификатор в короткой декларации", $var_pos);
            return;
        }

        my $var_name = $identifier->{Text};

        if (exists $self->{symbol_table}{scopes}{$scope}{constants}{$var_name}) {
            $self->add_error("Идентификатор '$var_name' уже используется как константа в области '$scope'", $var_pos);
            return;
        }
        if (exists $self->{symbol_table}{functions}{$var_name}) {
            $self->add_error("Идентификатор '$var_name' уже используется как имя функции", $var_pos);
            return;
        }

        my $right_type;
        # Проверяем, является ли выражение FunctionCall
        if (exists $expression->{type} && $expression->{type} eq 'Expression' && exists $expression->{value} &&
            exists $expression->{value}{type} && $expression->{value}{type} eq 'FunctionCall') {
            my $func_call = $expression->{value};
            if (exists $func_call->{return_type}) {
                $right_type = $func_call->{return_type};
            } elsif (exists $func_call->{name} && exists $self->{symbol_table}{functions}{$func_call->{name}}) {
                $right_type = $self->{symbol_table}{functions}{$func_call->{name}}{return_types}[0] || 'unknown';
            } else {
                $right_type = 'unknown';
            }
        } else {
            $right_type = $self->get_expression_type($expression->{type} eq 'Expression' ? $expression->{value} : $expression);
        }

        if ($right_type eq 'unknown' || $right_type eq 'auto') {
            $self->add_error("Неизвестный или неподдерживаемый тип в правой части короткой декларации", $expression->{Pos} || $node->{Pos} || 0);
            return;
        }

        $self->{symbol_table}{scopes}{$scope}{variables}{$var_name} = {
            type => $right_type,
            pos => $var_pos,
            value => $expression
        };
    }
}

# Вспомогательная функция для определения типа выражения
sub get_expression_type {
    my ($self, $value) = @_;
    print "get_expression_type\n";

    if ($value->{type} eq 'Expression' && exists $value->{value}) {
        return $self->get_expression_type($value->{value});
    }
    elsif ($value->{type} eq 'FunctionCall') {
        my $func_name = $value->{name};
        if (exists $self->{symbol_table}{functions}{$func_name}) {
            my $func_info = $self->{symbol_table}{functions}{$func_name};
            if (@{$func_info->{return_types}} == 1) {
                return $func_info->{return_types}[0];
            } elsif (@{$func_info->{return_types}} > 1) {
                $self->add_error(
                    "Функция '$func_name' возвращает несколько значений, ожидается одно для декларации",
                    $value->{Pos} || 0
                );
                return 'unknown';
            } else {
                $self->add_error(
                    "Функция '$func_name' не возвращает значений, нельзя использовать в декларации",
                    $value->{Pos} || 0
                );
                return 'unknown';
            }
        } else {
            $self->add_error(
                "Функция '$func_name' не найдена в таблице символов",
                $value->{Pos} || 0
            );
            return 'unknown';
        }
    } elsif ($value->{type} eq 'StructInitialization') {
        my $struct_node = $value;
        if (exists $value->{value} && $value->{value}{type} eq 'StructInitialization') {
            $struct_node = $value->{value};
        }

        my $struct_name = $struct_node->{struct_name};
        unless ($struct_name && exists $self->{symbol_table}{types}{$struct_name}) {
            $self->add_error(
                "Тип '$struct_name' не определен",
                $struct_node->{Pos} || $value->{Pos} || 0
            );
            return 'unknown';
        }

        my $fields = $struct_node->{fields} || [];
        my $struct_fields = $self->{symbol_table}{types}{$struct_name}{fields};

        for my $field (@$fields) {
            my $field_name = $field->{name};
            unless ($field_name && exists $struct_fields->{$field_name}) {
                $self->add_error(
                    "Поле '$field_name' не определено в структуре '$struct_name'",
                    $field->{value}{Pos} || $struct_node->{Pos} || $value->{Pos} || 0
                );
                return 'unknown';
            }

            my $field_value_type = $self->get_type($field->{value});
            my $expected_type = $struct_fields->{$field_name};

            if ($field_value_type eq 'unknown') {
                $self->add_error(
                    "Неизвестный тип значения для поля '$field_name' в структуре '$struct_name'",
                    $field->{value}{Pos} || $struct_node->{Pos} || $value->{Pos} || 0
                );
                return 'unknown';
            }

            unless ($field_value_type eq $expected_type) {
                $self->add_error(
                    "Несовместимый тип для поля '$field_name' в структуре '$struct_name': ожидался $expected_type, получен $field_value_type",
                    $field->{value}{Pos} || $struct_node->{Pos} || $value->{Pos} || 0
                );
                return 'unknown';
            }
        }

        return $struct_name;
    } elsif ($value->{type} eq 'Array') {
        my $array_type = $value->{array_type};
        unless ($array_type && exists $self->{symbol_table}{types}{$array_type}) {
            $self->add_error(
                "Тип массива '$array_type' не определен",
                $value->{Pos} || 0
            );
            return 'unknown';
        }

        my $elements = $value->{elements} || [];
        my $struct_fields = $self->{symbol_table}{types}{$array_type}{fields};

        for my $element (@$elements) {
            unless ($element->{type} eq 'StructInitialization') {
                $self->add_error(
                    "Элемент массива должен быть инициализацией структуры, получен тип '$element->{type}'",
                    $element->{Pos} || $value->{Pos} || 0
                );
                return 'unknown';
            }

            # Устанавливаем struct_name для элемента, если оно null или отсутствует
            $element->{struct_name} = $array_type unless exists $element->{struct_name} && $element->{struct_name};

            my $fields = $element->{fields} || [];
            for my $field (@$fields) {
                my $field_name = $field->{name};
                unless ($field_name && exists $struct_fields->{$field_name}) {
                    $self->add_error(
                        "Поле '$field_name' не определено в структуре '$array_type'",
                        $field->{value}{Pos} || $element->{Pos} || $value->{Pos} || 0
                    );
                    return 'unknown';
                }

                my $field_value_type = $self->get_type($field->{value});
                my $expected_type = $struct_fields->{$field_name};

                if ($field_value_type eq 'unknown') {
                    $self->add_error(
                        "Неизвестный тип значения для поля '$field_name' в структуре '$array_type'",
                        $field->{value}{Pos} || $element->{Pos} || $value->{Pos} || 0
                    );
                    return 'unknown';
                }

                unless ($field_value_type eq $expected_type) {
                    $self->add_error(
                        "Несовместимый тип для поля '$field_name' в структуре '$array_type': ожидался $expected_type, получен $field_value_type",
                        $field->{value}{Pos} || $element->{Pos} || $value->{Pos} || 0
                    );
                    return 'unknown';
                }
            }

            # Проверка, что все обязательные поля структуры присутствуют
            for my $field_name (keys %$struct_fields) {
                unless (grep { $_->{name} eq $field_name } @$fields) {
                    $self->add_error(
                        "Пропущено обязательное поле '$field_name' в инициализации структуры '$array_type'",
                        $element->{Pos} || $value->{Pos} || 0
                    );
                    return 'unknown';
                }
            }
        }

        return "[]$array_type";
    } elsif ($value->{type} eq 'FieldAccess') {
        my $object_name = $value->{object}{value};
        my $field_name = $value->{field}{value};
        my $object_type = $self->get_variable_type($object_name);

        # print "FieldAccess: object=$object_name, type=$object_type, field=$field_name\n";

        unless ($object_type && $object_type ne 'unknown') {
            $self->add_error(
                "Объект '$object_name' не определен или имеет неизвестный тип",
                $value->{object}{Pos} || $value->{Pos} || 0
            );
            return 'unknown';
        }

        unless (exists $self->{symbol_table}{types}{$object_type}) {
            $self->add_error(
                "Тип '$object_type' объекта '$object_name' не является структурой",
                $value->{object}{Pos} || $value->{Pos} || 0
            );
            return 'unknown';
        }

        my $struct_fields = $self->{symbol_table}{types}{$object_type}{fields};
        unless ($field_name && exists $struct_fields->{$field_name}) {
            $self->add_error(
                "Поле '$field_name' не определено в структуре '$object_type'",
                $value->{field}{Pos} || $value->{Pos} || 0
            );
            return 'unknown';
        }

        my $field_type = $struct_fields->{$field_name};
        # print "Resolved field type: $field_type\n";
        return $field_type;
    } else {
        my $type = $self->get_type($value);
        # print "Delegated to get_type: $type\n";
        return $type;
    }
}

# Check constant declarations
sub check_const_declaration {
    my ($self, $node) = @_;

    unless ($node->{type} eq 'ConstDeclaration' && exists $node->{nodes} && ref($node->{nodes}) eq 'ARRAY') {
        $self->add_error("Некорректная структура декларации константы", $node->{Pos} || 0);
        return;
    }

    my $nodes = $node->{nodes};
    my ($const_keyword, $identifier, $type_node, $assign, $value_node, $semicolon);
    my $has_type = 0;
    my $node_index = 0;

    # Проверяем токен 'const'
    if ($node_index < @$nodes && $nodes->[$node_index]{Name} eq 'const') {
        $const_keyword = $nodes->[$node_index];
        $node_index++;
    } else {
        $self->add_error("Ожидалось ключевое слово 'const'", $node->{Pos} || 0);
        return;
    }

    # Проверяем идентификатор
    if ($node_index < @$nodes && $nodes->[$node_index]{Name} =~ /^id-/) {
        $identifier = $nodes->[$node_index];
        $node_index++;
    } else {
        $self->add_error("Ожидалось имя константы", $nodes->[$node_index-1]{Pos} || $node->{Pos} || 0);
        return;
    }

    # Проверяем, есть ли тип
    if ($node_index < @$nodes && $nodes->[$node_index]{Name} eq 'Type') {
        $type_node = $nodes->[$node_index];
        $has_type = 1;
        $node_index++;
    }

    # Проверяем оператор присваивания
    if ($node_index < @$nodes && $nodes->[$node_index]{Name} eq 'assignment') {
        $assign = $nodes->[$node_index];
        $node_index++;
    } else {
        $self->add_error("Ожидался оператор присваивания '='", $nodes->[$node_index-1]{Pos} || $node->{Pos} || 0);
        return;
    }

    # Проверяем значение
    if ($node_index < @$nodes && $nodes->[$node_index]{Name} =~ /^(number|string|boolean)$/) {
        $value_node = $nodes->[$node_index];
        $node_index++;
    } else {
        $self->add_error("Ожидалось значение константы (число, строка или булево)", $nodes->[$node_index-1]{Pos} || $node->{Pos} || 0);
        return;
    }

    if ($node_index < @$nodes && $nodes->[$node_index]{Name} eq 'semicolon') {
        $semicolon = $nodes->[$node_index];
    }

    my $const_name = $identifier->{Text};
    my $declared_type = $has_type ? $type_node->{Text} : 'auto';
    my $value_pos = $value_node->{Pos} || $node->{Pos} || 0;
    my $const_pos = $identifier->{Pos} || $node->{Pos} || 0;

    my $scope = $self->{current_scope} || '-Global-';
    
    if (exists $self->{symbol_table}{scopes}{$scope}{variables}{$const_name}) {
        $self->add_error("Идентификатор '$const_name' уже используется как переменная в области '$scope'", $const_pos);
        return;
    }
    if (exists $self->{symbol_table}{functions}{$const_name}) {
        $self->add_error("Идентификатор '$const_name' уже используется как имя функции", $const_pos);
        return;
    }

    my $value_type;
    if ($value_node->{Name} eq 'number') {
        $value_type = $value_node->{Text} =~ /\./ ? 'float64' : 'int';
    } elsif ($value_node->{Name} eq 'string') {
        $value_type = 'string';
    } elsif ($value_node->{Name} eq 'boolean') {
        $value_type = 'bool';
    } else {
        $value_type = 'unknown';
    }

    if ($declared_type ne 'auto' && $declared_type ne $value_type) {
        $self->add_error(
            "Несовместимые типы: нельзя присвоить " . $value_type . " константе типа " . $declared_type, $value_pos
        );
        return;
    }

    # Добавляем константу в таблицу символов
    $self->{symbol_table}{scopes}{$scope}{constants}{$const_name} = {
        type => $declared_type eq 'auto' ? $value_type : $declared_type,
        pos => $const_pos,
        value => $value_node->{Text}
    };
}

# Check binary operations
sub check_binary_operation {
    my ($self, $node) = @_;

    unless (exists $node->{left} && exists $node->{right} && exists $node->{operator}) {
        $self->add_error("Некорректная структура бинарной операции", $node->{Pos} || 0);
        return;
    }

    # Проверяем, что идентификаторы объявлены до использования
    if (exists $node->{left}{type} && $node->{left}{type} eq 'Identifier') {
        $self->check_variable_usage($node->{left}{value}, $node->{left}{Pos} || $node->{Pos} || 0);
    }
    if (exists $node->{right}{type} && $node->{right}{type} eq 'Identifier') {
        $self->check_variable_usage($node->{right}{value}, $node->{right}{Pos} || $node->{Pos} || 0);
    }

    my $left_type  = $self->get_type($node->{left});
    my $right_type = $self->get_type($node->{right});
    my $operator   = $node->{operator}{value};

    if ($left_type eq 'unknown' || $right_type eq 'unknown') {
        $self->add_error("Неизвестный тип в бинарной операции", $node->{operator}{Pos} || $node->{Pos} || 0);
        return;
    }

    if ($left_type ne $right_type) {
        $self->add_error("Несовместимые типы: " . $left_type . " и " . $right_type . " для оператора $operator", $node->{operator}{Pos} || $node->{Pos} || 0);
        return;
    }

    if ($operator eq '+' && $left_type !~ /^(int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|string)$/) {
        $self->add_error("Оператор + применим только к целочисленным, числам с плавающей точкой или строкам, получен " . $left_type, $node->{operator}{Pos} || $node->{Pos} || 0);
    } elsif ($operator =~ /^(-|\*|\/)$/ && $left_type !~ /^(int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64)$/) {
        $self->add_error("Оператор $operator применим только к целочисленным или числам с плавающей точкой, получен " . $left_type, $node->{operator}{Pos} || $node->{Pos} || 0);
    } elsif ($operator =~ /^(<|>|<=|>=|==|!=)$/ && $left_type !~ /^(int|int8|int16|int32|int64|uint|uint8|uint16|uint32|uint64|float32|float64|string|bool)$/) {
        $self->add_error("Оператор $operator применим только к целочисленным, числам с плавающей точкой, строкам или логическим значениям, получен " . $left_type, $node->{operator}{Pos} || $node->{Pos} || 0);
    } elsif ($operator =~ /^(&&\|\|)$/ && $left_type ne 'bool') {
        $self->add_error("Оператор $operator применим только к логическим значениям, получен " . $left_type, $node->{operator}{Pos} || $node->{Pos} || 0);
    }
}

# Check function call
sub check_function_call {
    my ($self, $node) = @_;

    unless ($node->{type} eq 'FunctionCall' && exists $node->{name}) {
        $self->add_error("Некорректная структура вызова функции", $node->{Pos} || 0);
        return;
    }

    my $func_name = $node->{name};
    my $package = $node->{package};
    my $args = $node->{args} || [];
    my $pos = $node->{Pos} || 0;

    # Проверяем, что идентификаторы в аргументах объявлены
    for my $arg (@$args) {
        if (exists $arg->{type} && $arg->{type} eq 'Identifier') {
            $self->check_variable_usage($arg->{value}, $arg->{Pos} || $pos);
        }
    }

    my @sorted_args = @$args;
    my $func_info;

    if (defined $package && $package ne '') {
        $pos = $pos || $node->{nodes}[0]{Pos} || 0;
        unless (exists $BuiltInFunctions::FUNCTIONS{$package}) {
            $self->add_error("Пакет '$package' не поддерживается", $pos);
            return;
        }
        unless (exists $BuiltInFunctions::FUNCTIONS{$package}{$func_name}) {
            $self->add_error("Функция '$func_name' не найдена в пакете '$package'", $pos);
            return;
        }
        $func_info = $BuiltInFunctions::FUNCTIONS{$package}{$func_name};
        return $self->check_builtin_function($node, $func_name, $package, $func_info, \@sorted_args, $pos);
    } else {
        if (exists $BuiltInFunctions::FUNCTIONS{'builtin'}{$func_name}) {
            $func_info = $BuiltInFunctions::FUNCTIONS{'builtin'}{$func_name};
            return $self->check_builtin_function($node, $func_name, 'builtin', $func_info, \@sorted_args, $pos);
        } elsif (exists $self->{symbol_table}{functions}{$func_name}) {
            $func_info = $self->{symbol_table}{functions}{$func_name};
        } else {
            $pos = $pos || ($node->{args}[0]{Pos} // undef) if @{$node->{args}};
            $self->add_error("Функция '$func_name' не объявлена", $pos || $node->{Pos} || 0);
            return;
        }
    }

    my $expected_params = $func_info->{params} || [];
    my $expected_count = @$expected_params;
    my $is_variadic = $expected_count > 0 && $expected_params->[-1]{type} =~ /^\.\.\./;

    if ($is_variadic) {
        unless (@sorted_args >= $expected_count - 1) {
            $self->add_error(
                "Неверное количество аргументов в вызове функции '$func_name': ожидалось минимум " . ($expected_count - 1) . ", получено " . @sorted_args,
                $pos
            );
            return;
        }
    } else {
        unless (@sorted_args == $expected_count) {
            $self->add_error(
                "Неверное количество аргументов в вызове функции '$func_name': ожидалось $expected_count, получено " . @sorted_args,
                $pos
            );
            return;
        }
    }

    for my $i (0..$#sorted_args) {
        my $arg = $sorted_args[$i];
        my $param = $i < $expected_count ? $expected_params->[$i] : $expected_params->[-1];
        if ($i < $expected_count) {
            unless ($param->{param_pos} == $i) {
                $self->add_error(
                    "Неверный порядок параметра '$param->{name}' в функции '$func_name': ожидалась позиция $param->{param_pos}, но найдена $i",
                    $arg->{Pos} || $pos
                );
                return;
            }
        }

        my $arg_type = $self->get_type($arg);
        my $expected_type = $param->{type};
        if ($is_variadic && $i >= $expected_count - 1) {
            $expected_type =~ s/^\.\.\.//;
        }

        if ($expected_type eq 'interface{}' || $expected_type eq 'Type' || $arg_type eq $expected_type) {
            next;
        } else {
            $self->add_error(
                "Несовместимый тип аргумента для параметра '$param->{name}' в функции '$func_name': ожидался $expected_type, получен $arg_type",
                $arg->{Pos} || $pos
            );
            return;
        }
    }

    if (@{$func_info->{return_types}}) {
        $node->{return_type} = $func_info->{return_types}[0];
    }
}

# Check builtin fuctions
sub check_builtin_function {
    my ($self, $node, $func_name, $package, $func_info, $sorted_args, $pos) = @_;

    # Проверяем, что идентификаторы в аргументах объявлены
    for my $arg (@$sorted_args) {
        if (exists $arg->{type} && $arg->{type} eq 'Identifier') {
            $self->check_variable_usage($arg->{value}, $arg->{Pos} || $pos);
        }
    }

    if ($func_name eq 'append' && (!defined $package || $package eq 'builtin')) {
        unless (@$sorted_args >= 1) {
            $self->add_error(
                "Функция 'append' требует как минимум один аргумент (slice)",
                $pos
            );
            return 0;
        }

        my $slice_arg = $sorted_args->[0];
        my $slice_type = $self->get_type($slice_arg);

        unless ($slice_type =~ /^\[\](.+)$/) {
            $self->add_error(
                "Первый аргумент функции 'append' должен быть массивом, получен '$slice_type'",
                $slice_arg->{Pos} || $pos
            );
            return 0;
        }
        my $element_type = $1;

        for my $i (1..$#$sorted_args) {
            my $arg = $sorted_args->[$i];
            my $arg_type = $self->get_type($arg);

            # Обработка auto
            if ($arg_type eq 'auto' && exists $arg->{value}) {
                $arg_type = $self->get_type($arg->{value});
            }

            unless ($arg_type eq $element_type) {
                $self->add_error(
                    "Аргумент на позиции $i функции 'append' должен иметь тип '$element_type', получен '$arg_type'",
                    $arg->{Pos} || $pos
                );
                return 0;
            }
        }
        $node->{return_type} = $slice_type;
        return 1;
    }

    if ($func_name eq 'Printf' && $package eq 'fmt') {
        unless (@$sorted_args >= 1) {
            $self->add_error(
                "Функция 'fmt.Printf' требует как минимум один аргумент (строка формата)",
                $pos
            );
            return 0;
        }

        my $format_arg = $sorted_args->[0];
        my $format_type = $self->get_type($format_arg);

        unless ($format_type eq 'string') {
            $self->add_error(
                "Первый аргумент функции 'fmt.Printf' должен быть строкой формата, получен '$format_type'",
                $format_arg->{Pos} || $pos
            );
            return 0;
        }

        # Остальные аргументы — вариадические (...interface{}), принимают любой тип
        for my $i (1..$#$sorted_args) {
            my $arg = $sorted_args->[$i];
            my $arg_type = $self->get_type($arg);
            if ($arg_type eq 'unknown') {
                $self->add_error(
                    "Неизвестный тип аргумента на позиции $i в функции 'fmt.Printf'",
                    $arg->{Pos} || $pos
                );
                return 0;
            }
        }

        $node->{return_type} = 'int';
        return 1;
    }

    # Другие встроенные функции
    my $expected_params = $func_info->{params} || [];
    my $expected_count = @$expected_params;
    my $is_variadic = $expected_count > 0 && $expected_params->[-1]{type} =~ /^\.\.\./;

    if ($is_variadic) {
        unless (@$sorted_args >= $expected_count - 1) {
            $self->add_error(
                "Неверное количество аргументов в вызове функции '$func_name': ожидалось минимум " . ($expected_count - 1) . ", получено " . @$sorted_args,
                $pos
            );
            return 0;
        }
    } else {
        unless (@$sorted_args == $expected_count) {
            $self->add_error(
                "Неверное количество аргументов в вызове функции '$func_name': ожидалось $expected_count, получено " . @$sorted_args,
                $pos
            );
            return 0;
        }
    }

    for my $i (0..$#$sorted_args) {
        my $arg = $sorted_args->[$i];
        my $param = $i < $expected_count ? $expected_params->[$i] : $expected_params->[-1];
        if ($i < $expected_count) {
            unless ($param->{param_pos} == $i) {
                $self->add_error(
                    "Неверный порядок параметра '$param->{name}' в функции '$func_name': ожидалась позиция $param->{param_pos}, но найдена $i",
                    $arg->{Pos} || $pos
                );
                return 0;
            }
        }

        my $arg_type = $self->get_type($arg);
        my $expected_type = $param->{type};
        if ($is_variadic && $i >= $expected_count - 1) {
            $expected_type =~ s/^\.\.\.//;
        }

        if ($expected_type eq 'interface{}' || $expected_type eq 'Type' || $arg_type eq $expected_type) {
            next;
        } else {
            $self->add_error(
                "Несовместимый тип аргумента для параметра '$param->{name}' в функции '$func_name': ожидался $expected_type, получен $arg_type",
                $arg->{Pos} || $pos
            );
            return 0;
        }
    }

    if (@{$func_info->{return_types}}) {
        $node->{return_type} = $func_info->{return_types}[0];
    }
    return 1;
}

# Check for loop
sub check_for_loop {
    my ($self, $node) = @_;
    unless ($node->{type} eq 'ForLoop') {
        $self->add_error("Ожидался узел типа 'ForLoop'", $node->{Pos} || 0);
        return;
    }

    # Сохраняем текущую область видимости
    my $old_scope = $self->{current_scope} || '-Global-';

    # Находим позицию ключевого слова 'for' в nodes
    my $for_pos = 'unknown';
    for my $n (@{$node->{nodes} || []}) {
        if ($n->{Name} eq 'for' && exists $n->{Pos}) {
            $for_pos = $n->{Pos};
            last;
        }
    }

    my $for_scope = $old_scope . "_for_" . $for_pos;
    # Создаем область в scopes
    $self->{symbol_table}{scopes}{$for_scope} = { variables => {}, inner_scopes => [] };
    $self->{current_scope} = $for_scope;

    # Инициализируем inner_scopes для родительской области, если не существует
    $self->{symbol_table}{scopes}{$old_scope}{inner_scopes} = [] unless exists $self->{symbol_table}{scopes}{$old_scope}{inner_scopes};

    # Проверка переменной в range
    if ($node->{loop_type} eq 'range' && exists $node->{range} && ref($node->{range}) eq 'HASH') {
        my $range_var = $node->{range}{value};
        # Проверяем, что переменная range объявлена до использования
        if ($node->{range}{type} eq 'Identifier') {
            $self->check_variable_usage($range_var, $node->{range}{Pos} || $node->{Pos} || 0);
        }
        my $range_type = $self->get_variable_type($range_var, $node->{range}{Pos} || $node->{Pos} || 0);
        unless ($range_type ne 'unknown' && $range_type =~ /^\[\](.+)$/) {
            $self->add_error(
                "Переменная '$range_var' в range должна быть массивом, получен тип '$range_type'",
                $node->{range}{Pos} || $node->{Pos} || 0
            );
            return;
        }

        my $element_type = $1;
        my $index_type = 'int';

        my $nodes = $node->{nodes} || [];
        my ($index_var, $value_var);
        for my $i (0..$#$nodes) {
            if ($nodes->[$i]{Name} =~ /^id-/ && exists $nodes->[$i]{Text}) {
                if (!defined $index_var) {
                    $index_var = $nodes->[$i];
                } elsif (!defined $value_var) {
                    $value_var = $nodes->[$i];
                }
            }
            last if defined $index_var && defined $value_var;
        }

        if ($index_var) {
            my $var_name = $index_var->{Text};
            my $var_pos = $index_var->{Pos} || $node->{Pos} || 0;
            $self->{symbol_table}{scopes}{$for_scope}{variables}{$var_name} = {
                type => $index_type,
                pos => $var_pos
            };
        }

        if ($value_var) {
            my $var_name = $value_var->{Text};
            my $var_pos = $value_var->{Pos} || $node->{Pos} || 0;
            $self->{symbol_table}{scopes}{$for_scope}{variables}{$var_name} = {
                type => $element_type,
                pos => $var_pos
            };
        }
    }

    # Обработка инициализатора (init) для стандартных циклов
    if (exists $node->{init} && ref($node->{init}) eq 'HASH') {
        $node->{init}{parent_type} = 'ForLoop';
        # Анализируем init с областью цикла
        $self->{current_scope} = $for_scope;
        $self->analyze_node($node->{init});
        # Удаляем переменные из родительской области, если они были добавлены
        if ($node->{init}{type} eq 'ShortVariableDeclaration' && exists $node->{init}{nodes}) {
            my $nodes = $node->{init}{nodes};
            for my $n (@$nodes) {
                if ($n->{Name} =~ /^id-/ && exists $n->{Text} && exists $n->{Pos}) {
                    my $var_name = $n->{Text};
                    delete $self->{symbol_table}{scopes}{$old_scope}{variables}{$var_name};
                }
            }
        }
    }

    # Обработка условия (condition)
    if (exists $node->{condition} && ref($node->{condition}) eq 'HASH') {
        $self->{current_scope} = $for_scope;
        $self->analyze_node($node->{condition});
    }

    # Обработка итерации (iteration)
    if (exists $node->{iteration} && ref($node->{iteration}) eq 'HASH') {
        $self->{current_scope} = $for_scope;
        $self->analyze_node($node->{iteration});
    }

    # Обработка тела цикла (body)
    if (exists $node->{body} && ref($node->{body}) eq 'ARRAY') {
        # Устанавливаем область цикла для тела
        $self->{current_scope} = $for_scope;
        for my $child (@{$node->{body}}) {
            $self->traverse_cst($child);
        }
    }

    # Добавляем область цикла в inner_scopes родительской области
    push @{$self->{symbol_table}{scopes}{$old_scope}{inner_scopes}}, {
        name => $for_scope,
        variables => { %{$self->{symbol_table}{scopes}{$for_scope}{variables}} },
        inner_scopes => [ @{$self->{symbol_table}{scopes}{$for_scope}{inner_scopes}} ]
    };

    # Восстанавливаем область видимости
    $self->{current_scope} = $old_scope;
}

sub check_variable_usage {
    my ($self, $var_name, $pos) = @_;
    my $type = $self->get_variable_type($var_name, $pos);
    if ($type eq 'unknown') {
        my $message = "Переменная '$var_name' используется до её декларации";
        for my $error (@{$self->{errors}}) {
            if ($error->{message} eq $message && $error->{pos} == $pos) {
                return;
            }
        }
        $self->add_error($message, $pos);
    }
}
1;
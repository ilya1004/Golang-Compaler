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

# Translate type names to Russian
sub translate_type {
    my ($self, $type) = @_;
    print "translate_type\n";
    print "--------------------------------------------------------\n";
    print Dumper($type), "\n";
    my %type_translations = (
        # 'int'      => 'целочисленный',
        # 'int8'     => 'целочисленный (8 бит)',
        # 'int16'    => 'целочисленный (16 бит)',
        # 'int32'    => 'целочисленный (32 бита)',
        # 'int64'    => 'целочисленный (64 бита)',
        # 'uint'     => 'беззнаковый целочисленный',
        # 'uint8'    => 'беззнаковый целочисленный (8 бит)',
        # 'uint16'   => 'беззнаковый целочисленный (16 бит)',
        # 'uint32'   => 'беззнаковый целочисленный (32 бита)',
        # 'uint64'   => 'беззнаковый целочисленный (64 бита)',
        # 'float32'  => 'число с плавающей точкой (32 бита)',
        # 'float64'  => 'число с плавающей точкой (64 бита)',
        # 'string'   => 'строка',
        # 'bool'     => 'логический',
        # 'unknown'  => 'неизвестный',
        # 'auto'     => 'автоматический'
    );
    return $type_translations{$type} || $type;
}

# Get the type of an expression
sub get_type {
    my ($self, $expr) = @_;
    print "get_type\n";
    # print Dumper($expr), "\n";
    return 'unknown' unless ref($expr) eq 'HASH';

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
    }
    return 'unknown';
}

# Get the type of a variable from the symbol table
sub get_variable_type {
    my ($self, $var_name) = @_;
    print "get_variable_type\n";
    print "$var_name\n";
    my $scope = $self->{current_scope};
    if (exists $self->{symbol_table}{scopes}{$scope}{variables}{$var_name}) {
        my $var_info = $self->{symbol_table}{scopes}{$scope}{variables}{$var_name};
        # print Dumper($self->{symbol_table}{scopes}{$scope}), "\n";
        if ($var_info->{type} eq 'auto' && exists $var_info->{value}) {
            return "auto"
        }
        return $var_info->{type};
    } elsif (exists $self->{symbol_table}{scopes}{"-Global-"}{variables}{$var_name}) {
        my $var_info = $self->{symbol_table}{scopes}{"-Global-"}{variables}{$var_name};
        if ($var_info->{type} eq 'auto' && exists $var_info->{value}) {
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

    unless (($node->{type} eq 'VariableDeclaration' || $node->{type} eq 'ShortVariableDeclaration') && 
            exists $node->{nodes} && ref($node->{nodes}) eq 'ARRAY') {
        $self->add_error("Некорректная структура декларации переменной", $node->{Pos} || 0);
        die "Invalid declaration structure at position " . ($node->{Pos} || 0);
    }

    my $nodes = $node->{nodes};
    my $is_var_declaration = ($node->{type} eq 'VariableDeclaration');
    my $scope = $self->{current_scope} || '-Global-';
    print "Current scope: $scope\n";

    # Для ShortVariableDeclaration в цикле for область видимости уже создана в check_for_loop
    # my $old_scope = $scope;
    # if ($node->{type} eq 'ShortVariableDeclaration' && exists $node->{parent_type} && $node->{parent_type} eq 'ForLoop') {
    #     # Область видимости уже установлена в check_for_loop
    #     print "Using ForLoop scope: $scope\n";
    # }

    if ($is_var_declaration) {
        unless (scalar(@{$nodes}) >= 3 && $nodes->[0]{Name} eq 'var') {
            $self->add_error("Некорректная структура декларации переменной с var", $node->{Pos} || 0);
            die "Invalid var declaration structure at position " . ($node->{Pos} || 0);
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
            die "Expected at least one identifier in var declaration at position " . ($nodes->[1]{Pos} || $node->{Pos} || 0);
        }

        my $declared_type = $nodes->[$i];
        unless ($declared_type && $declared_type->{Name} eq 'Type' && exists $declared_type->{Text}) {
            $self->add_error("Ожидается тип в декларации var", $declared_type ? $declared_type->{Pos} || 0 : $node->{Pos} || 0);
            die "Expected type in var declaration at position " . ($declared_type ? $declared_type->{Pos} || 0 : $node->{Pos} || 0);
        }

        my $declared_type_value = $declared_type->{Text};
        my $has_expression = ($i + 1 < @$nodes && $nodes->[$i + 1]{Name} eq 'equal');

        print "----------------------------\n";
        print Dumper($declared_type), "\n";

        if ($has_expression) {
            unless ($i + 2 < @$nodes) {
                $self->add_error("Ожидается выражение после '=' в декларации var", $nodes->[$i + 1]{Pos} || $node->{Pos} || 0);
                die "Expected expression after '=' in var declaration at position " . ($nodes->[$i + 1]{Pos} || $node->{Pos} || 0);
            }
            my $expression = $nodes->[$i + 2];
            my $right_type = $self->get_expression_type($expression->{type} eq 'Expression' ? $expression->{value} : $expression);

            if ($right_type eq 'unknown') {
                $self->add_error("Неизвестный тип в правой части декларации", $expression->{Pos} || $node->{Pos} || 0);
                die "Unknown type in right side of declaration at position " . ($expression->{Pos} || $node->{Pos} || 0);
            }

            if ($declared_type_value ne $right_type) {
                $self->add_error(
                    "Несовместимые типы: нельзя присвоить " . $self->translate_type($right_type) . 
                    " переменной типа " . $self->translate_type($declared_type_value), 
                    $expression->{Pos} || $node->{Pos} || 0
                );
                die "Type mismatch in var declaration at position " . ($expression->{Pos} || $node->{Pos} || 0);
            }
        }

        for my $identifier (@identifiers) {
            my $var_name = $identifier->{Text};
            my $var_pos = $identifier->{Pos} || $node->{Pos} || 0;
            my $var_type = $self->get_variable_type($var_name);

            if ($var_type eq 'unknown') {
                $self->add_error("Переменная '$var_name' не объявлена в таблице символов", $var_pos);
                die "Variable '$var_name' not declared in symbol table at position $var_pos";
            }

            if ($var_type eq 'auto' && $has_expression) {
                print "Updating type for $var_name in scope $scope to $declared_type_value\n";
                if (exists $self->{symbol_table}{scopes}{$scope}{variables}{$var_name}) {
                    $self->{symbol_table}{scopes}{$scope}{variables}{$var_name}{type} = $declared_type_value;
                } elsif (exists $self->{symbol_table}{scopes}{"-Global-"}{variables}{$var_name}) {
                    $self->{symbol_table}{scopes}{"-Global-"}{variables}{$var_name}{type} = $declared_type_value;
                }
                print Dumper($self->{symbol_table}{scopes}{$scope}{variables}), "\n";
            }
        }
    } else {
        unless (scalar(@{$nodes}) >= 3 && $nodes->[1]{Name} eq 'declaration' && $nodes->[1]{Text} eq ':=') {
            $self->add_error("Некорректная структура короткой декларации переменной", $node->{Pos} || 0);
            die "Invalid short declaration structure at position " . ($node->{Pos} || 0);
        }

        my $identifier = $nodes->[0];
        my $expression = $nodes->[2];
        my $var_pos = $identifier->{Pos} || $node->{Pos} || 0;

        unless ($identifier->{Name} =~ /^id-/ && exists $identifier->{Text}) {
            $self->add_error("Ожидается идентификатор в короткой декларации", $var_pos);
            die "Expected identifier in short declaration at position $var_pos";
        }

        my $var_name = $identifier->{Text};
        my $var_type = $self->get_variable_type($var_name);
        print "Checking variable $var_name, current type: $var_type\n";

        my $right_type = $self->get_expression_type($expression->{type} eq 'Expression' ? $expression->{value} : $expression);

        if ($var_type eq 'unknown') {
            $self->add_error("Переменная '$var_name' не объявлена в таблице символов", $var_pos);
            die "Variable '$var_name' not declared in symbol table at position $var_pos";
        }

        if ($right_type eq 'unknown') {
            $self->add_error("Неизвестный тип в правой части декларации", $expression->{Pos} || $node->{Pos} || 0);
            die "Unknown type in right side of declaration at position " . ($expression->{Pos} || $node->{Pos} || 0);
        }

        if ($var_type eq 'auto') {
            print "Updating type for $var_name in scope $scope to $right_type\n";
            if (exists $self->{symbol_table}{scopes}{$scope}{variables}{$var_name}) {
                $self->{symbol_table}{scopes}{$scope}{variables}{$var_name}{type} = $right_type;
            } elsif (exists $self->{symbol_table}{scopes}{"-Global-"}{variables}{$var_name}) {
                $self->{symbol_table}{scopes}{"-Global-"}{variables}{$var_name}{type} = $right_type;
            } else {
                $self->add_error("Переменная '$var_name' не найдена ни в текущей, ни в глобальной области видимости", $var_pos);
                die "Variable '$var_name' not found in current or global scope at position $var_pos";
            }
            print Dumper($self->{symbol_table}{scopes}{$scope}{variables}), "\n";
        } else {
            print "Warning: $var_name already has type $var_type, not updating to $right_type\n";
        }
    }
}

# Вспомогательная функция для определения типа выражения
sub get_expression_type {
    my ($self, $value) = @_;
    print "get_expression_type\n";
    print Dumper($value), "\n";

    if ($value->{type} eq 'FunctionCall') {
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
    } elsif ($value->{type} eq 'FieldAccess') {
        my $object_name = $value->{object}{value};
        my $field_name = $value->{field}{value};
        my $object_type = $self->get_variable_type($object_name);



        print "FieldAccess: object=$object_name, type=$object_type, field=$field_name\n";

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
        print "Resolved field type: $field_type\n";
        return $field_type;
    } else {
        my $type = $self->get_type($value);
        print "Delegated to get_type: $type\n";
        return $type;
    }
}

# Check constant declarations
sub check_const_declaration {
    my ($self, $node) = @_;
    print "check_const_declaration\n";

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

    # Проверяем точку с запятой (если есть)
    if ($node_index < @$nodes && $nodes->[$node_index]{Name} eq 'semicolon') {
        $semicolon = $nodes->[$node_index];
    }

    # Извлекаем информацию
    my $const_name = $identifier->{Text};
    my $declared_type = $has_type ? $type_node->{Text} : 'auto';
    my $value_pos = $value_node->{Pos} || $node->{Pos} || 0;

    # Определяем тип значения
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

    # print "------------------------\n";
    # print "Declared type: $declared_type\n";
    # print "Value type: $value_type\n";
    # print Dumper($identifier), "\n";

    # Проверяем наличие константы в таблице символов
    my $scope = $self->{current_scope} || '-Global-';
    unless (exists $self->{symbol_table}{scopes}{$scope}{constants}{$const_name}) {
        $self->add_error("Константа $const_name не объявлена в таблице символов", $identifier->{Pos} || $node->{Pos} || 0);
        return;
    }

    # Проверяем соответствие типов
    if ($declared_type ne 'auto' && $declared_type ne $value_type) {
        $self->add_error(
            "Несовместимые типы: нельзя присвоить " . $self->translate_type($value_type) . 
            " константе типа " . $self->translate_type($declared_type), 
            $value_pos
        );
        return;
    }

    # Обновляем таблицу символов, если тип auto
    if ($self->{symbol_table}{scopes}{$scope}{constants}{$const_name}{type} eq 'auto') {
        $self->{symbol_table}{scopes}{$scope}{constants}{$const_name}{type} = $value_type;
        # print Dumper($self->{symbol_table}{scopes}{$scope}{constants}), "\n";
    }
}

# Check function call
sub check_function_call {
    my ($self, $node) = @_;
    print "check_function_call\n";
    print Dumper($node), "\n";

    # Проверяем, что узел имеет тип FunctionCall
    unless ($node->{type} eq 'FunctionCall' && exists $node->{name}) {
        $self->add_error("Некорректная структура вызова функции", $node->{Pos} || 0);
        return;
    }

    my $func_name = $node->{name};
    my $package = $node->{package};
    my $args = $node->{args} || [];
    my $pos = $node->{Pos} || 0;

    # Сортируем аргументы по Pos
    my @sorted_args = sort { ($a->{Pos} || 0) <=> ($b->{Pos} || 0) } @$args;

    my $func_info;

    # Если пакет указан, ищем функцию в пакете
    if (defined $package && $package ne '') {
        unless (exists $BuiltInFunctions::FUNCTIONS{$package}) {
            $self->add_error("Пакет '$package' не поддерживается", $pos);
            return;
        }
        unless (exists $BuiltInFunctions::FUNCTIONS{$package}{$func_name}) {
            $self->add_error("Функция '$func_name' не найдена в пакете '$package'", $pos);
            return;
        }
        $func_info = $BuiltInFunctions::FUNCTIONS{$package}{$func_name};
    } else {
        # Если пакет не указан, сначала ищем в builtin, затем в таблице символов
        if (exists $BuiltInFunctions::FUNCTIONS{'builtin'}{$func_name}) {
            $func_info = $BuiltInFunctions::FUNCTIONS{'builtin'}{$func_name};
        } elsif (exists $self->{symbol_table}{functions}{$func_name}) {
            $func_info = $self->{symbol_table}{functions}{$func_name};
        } else {
            $self->add_error("Функция '$func_name' не объявлена", $pos);
            return;
        }
    }

    my $expected_params = $func_info->{params} || [];

    # Проверяем количество аргументов
    my $expected_count = scalar @$expected_params;
    my $actual_count = scalar @sorted_args;
    my $is_variadic = $expected_count > 0 && $expected_params->[-1]{type} =~ /^\.\.\./;

    if ($is_variadic) {
        unless ($actual_count >= $expected_count - 1) {
            $self->add_error(
                "Неверное количество аргументов в вызове функции '$func_name': ожидалось минимум " . ($expected_count - 1) . ", получено $actual_count",
                $pos
            );
            return;
        }
    } else {
        unless ($actual_count == $expected_count) {
            $self->add_error(
                "Неверное количество аргументов в вызове функции '$func_name': ожидалось $expected_count, получено $actual_count",
                $pos
            );
            return;
        }
    }

    # Специальная обработка для функции append
    if ($func_name eq 'append' && (!defined $package || $package eq 'builtin')) {
        unless ($actual_count >= 1) {
            $self->add_error(
                "Функция 'append' требует как минимум один аргумент (slice)",
                $pos
            );
            return;
        }

        # Первый аргумент — slice типа []T
        my $slice_arg = $sorted_args[0];
        my $slice_type = $self->get_type($slice_arg);

        # Проверяем, что первый аргумент — массив
        unless ($slice_type =~ /^\[\](.+)$/) {
            $self->add_error(
                "Первый аргумент функции 'append' должен быть массивом, получен '$slice_type'",
                $slice_arg->{Pos} || $pos
            );
            return;
        }
        my $element_type = $1;  # Базовый тип T (например, int для []int)

        # Проверяем остальные аргументы (elems)

        print "==================\n";
        print Dumper(@sorted_args), "\n";

        for my $i (1..$#sorted_args) {
            my $arg = $sorted_args[$i];
            print Dumper($arg), "\n";

            print "qweqwe\n";
            my $arg_type = $self->get_type($arg);
            print "qweqwe\n";

            print "$arg_type | $element_type\n";

            unless ($arg_type eq $element_type) {
                $self->add_error(
                    "Аргумент на позиции $i функции 'append' должен иметь тип '$element_type', получен '$arg_type'",
                    $arg->{Pos} || $pos
                );
                # die;
                return;
            }
        }

        # die;

        # Тип возвращаемого значения — тот же, что у slice
        $node->{return_type} = $slice_type;
        print "Function 'append' returns: $slice_type\n";
        return;
    }

    # Проверяем типы аргументов для остальных функций
    for my $i (0..$#sorted_args) {
        my $arg = $sorted_args[$i];
        my $param = $i < $expected_count ? $expected_params->[$i] : $expected_params->[-1];  # Для вариадических используем последний параметр

        # Проверяем, что param_pos соответствует индексу
        if ($i < $expected_count) {
            unless ($param->{param_pos} == $i) {
                $self->add_error(
                    "Неверный порядок параметра '$param->{name}' в функции '$func_name': ожидалась позиция $param->{param_pos}, но найдена $i",
                    $arg->{Pos} || $pos
                );
                return;
            }
        }

        # Определяем тип аргумента
        my $arg_type = $self->get_type($arg);
        my $expected_type = $param->{type};

        # Для вариадических параметров убираем префикс "..."
        if ($is_variadic && $i >= $expected_count - 1) {
            $expected_type =~ s/^\.\.\.//;
        }

        # Упрощенная проверка типов (interface{} принимает любой тип)
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

    # Проверка возвращаемых значений
    if (@{$func_info->{return_types}}) {
        my $return_type = $func_info->{return_types}[0];  # Предполагаем один возвращаемый тип
        $node->{return_type} = $return_type;
        print "Function '$func_name' returns: $return_type\n";
    }
}

sub check_for_loop {
    my ($self, $node) = @_;
    print "check_for_loop\n";
    print Dumper($node), "\n";

    unless ($node->{type} eq 'ForLoop') {
        $self->add_error("Ожидался узел типа 'ForLoop'", $node->{Pos} || 0);
        die "Expected 'ForLoop' node at position " . ($node->{Pos} || 0);
    }

    # Сохраняем текущую область видимости
    # my $old_scope = $self->{current_scope} || '-Global-';
    # Создаем новую область видимости для цикла
    # my $scope = $old_scope . "_for_" . ($node->{Pos} || 'unknown');
    # $self->{symbol_table}{scopes}{$scope} = { variables => {} } unless exists $self->{symbol_table}{scopes}{$scope};
    # $self->{current_scope} = $scope;
    # print "Created new scope for ForLoop: $scope\n";

    # Обработка инициализатора (init)
    if (exists $node->{init} && ref($node->{init}) eq 'HASH') {
        print "Processing ForLoop init\n";
        # Помечаем, что это часть ForLoop, для правильной обработки области видимости
        $node->{init}{parent_type} = 'ForLoop';
        $self->analyze_node($node->{init});
    }

    # Обработка условия (condition)
    if (exists $node->{condition} && ref($node->{condition}) eq 'HASH') {
        print "Processing ForLoop condition\n";
        $self->analyze_node($node->{condition});
    }

    # Обработка итерации (iteration)
    if (exists $node->{iteration} && ref($node->{iteration}) eq 'HASH') {
        print "Processing ForLoop iteration\n";
        $self->analyze_node($node->{iteration});
    }

    # Обработка тела цикла (body)
    if (exists $node->{body} && ref($node->{body}) eq 'ARRAY') {
        print "Processing ForLoop body\n";
        for my $child (@{$node->{body}}) {
            $self->traverse_cst($child);
        }
    }

    # Восстанавливаем область видимости
    # $self->{current_scope} = $old_scope;
    # print "Restored scope: $old_scope\n";
}


1;
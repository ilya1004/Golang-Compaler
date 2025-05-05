package Interpreter;
use strict;
use warnings;
use Data::Dumper;

# Конструктор интерпретатора
sub new {
    my ($class, $cst, $symbol_table, $imports, $debug_mode) = @_;
    my $self = {
        cst => $cst,
        symbol_table => $symbol_table,
        imports => $imports,
        scopes => [],           # Стек областей видимости
        functions => {},        # Хранилище функций
        return_value => undef,  # Для возврата значений из функций
        input_buffer => [],     # Буфер для имитации fmt.Scan
        current_function => undef, # Текущая функция
        debug_mode => $debug_mode // 0, # Режим отладки
        break_flag => 0,        # Флаг для break
    };
    bless $self, $class;
    $self->initialize();
    return $self;
}

# Инициализация: загрузка функций, констант и типов
sub initialize {
    my ($self) = @_;
    if ($self->{debug_mode}) {
        warn "initialize\n";
    }
    my $global_scope = {};
    
    # Загрузка глобальных констант
    my $global_symbols = $self->{symbol_table}{scopes}{'-Global-'};
    for my $const (keys %{$global_symbols->{constants}}) {
        $global_scope->{$const} = {
            type => $global_symbols->{constants}{$const}{type},
            value => $global_symbols->{constants}{$const}{value},
        };
    }
    
    # Загрузка функций
    while (my ($func_name, $func_data) = each %{$self->{symbol_table}{functions}}) {
        $self->{functions}{$func_name} = $func_data;
        $self->{functions}{$func_name}{node} = $self->find_function_node($func_name);
    }
    
    # Загрузка типов (структур)
    while (my ($type_name, $type_data) = each %{$self->{symbol_table}{types}}) {
        $global_scope->{$type_name} = {
            type => 'struct',
            fields => $type_data->{fields},
        };
    }
    
    push @{$self->{scopes}}, $global_scope;
}

# Поиск узла функции в CST
sub find_function_node {
    my ($self, $func_name) = @_;
    if ($self->{debug_mode}) {
        warn "find_function_node: $func_name\n";
    }
    for my $node (@{$self->{cst}{children}}) {
        if ($node->{type} eq 'FunctionDeclaration' && $node->{name} eq $func_name) {
            return $node;
        }
    }
    die "Function $func_name not found in CST";
}

# Основной метод интерпретации
sub interpret {
    my ($self) = @_;
    my $main_node = $self->find_function_node('main');
    $self->{current_function} = 'main';
    push @{$self->{scopes}}, {};
    $self->execute_block($main_node->{body});
    pop @{$self->{scopes}};
    $self->{current_function} = undef;
}

# Выполнение блока операторов
sub execute_block {
    my ($self, $block) = @_;
    if ($self->{debug_mode}) {
        warn "execute_block\n";
    }
    for my $statement (@$block) {
        last if defined $self->{return_value} || $self->{break_flag};
        $self->execute_statement($statement);
    }
}

# Выполнение одного оператора
sub execute_statement {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "execute_statement: $node->{type}\n";
    }
    my $type = $node->{type};

    if ($type eq 'VariableDeclaration') {
        $self->handle_variable_declaration($node);
    } elsif ($type eq 'ShortVariableDeclaration') {
        $self->handle_short_variable_declaration($node);
    } elsif ($type eq 'FunctionCall') {
        $self->handle_function_call($node);
    } elsif ($type eq 'IfStatement') {
        $self->handle_if_statement($node);
    } elsif ($type eq 'SwitchStatement') {
        $self->handle_switch_statement($node);
    } elsif ($type eq 'ReturnStatement') {
        $self->handle_return_statement($node);
    } elsif ($type eq 'ForLoop') {
        $self->handle_for_loop($node);
    } elsif ($type eq 'AssignmentExpression') {
        $self->handle_assignment_expression($node);
    } elsif ($type eq 'UnaryOperation') {
        $self->handle_unary_operation($node);
    } elsif ($type eq 'ControlStatement') {
        $self->handle_control_statement($node);
    } else {
        die "Unsupported statement type: $type";
    }
}

# Обработка объявления переменной (var)
sub handle_variable_declaration {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_variable_declaration\n";
    }
    my $var_name = $node->{nodes}[1]{Text};
    my $var_type = $node->{nodes}[2]{Text};
    my $value = $var_type =~ /^\[\]/ ? [] : $self->default_value($var_type);
    $self->current_scope()->{$var_name} = {
        type => $var_type,
        value => $value,
    };
}

# Обработка короткого объявления переменной (:=)
sub handle_short_variable_declaration {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_short_variable_declaration\n";
    }
    my $var_name = $node->{nodes}[0]{Text};
    my $value_node = $node->{nodes}[2]{value} // $node->{nodes}[2];
    my $value = $self->evaluate_expression($value_node);
    
    my $scope_name = $self->get_current_scope_name();
    my $inner_scopes = $self->{symbol_table}{scopes}{$scope_name}{inner_scopes} || [];
    my $var_type;
    
    # Проверяем внутренние области
    for my $inner_scope (@$inner_scopes) {
        my $inner_scope_name = $inner_scope->{name};
        my $inner_variables = $self->{symbol_table}{scopes}{$inner_scope_name}{variables};
        if (exists $inner_variables->{$var_name} && $inner_variables->{$var_name}{type} ne 'auto') {
            $var_type = $inner_variables->{$var_name}{type};
            last;
        }
    }
    
    # Если не найдено во внутренних областях, проверяем текущую область
    $var_type //= $self->{symbol_table}{scopes}{$scope_name}{variables}{$var_name}{type}
        // die "Type for $var_name not found in symbol table at scope $scope_name";
    
    $self->current_scope()->{$var_name} = {
        type => $var_type,
        value => $value,
    };
}

# Обработка присваивания
sub handle_assignment_expression {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_assignment_expression\n";
    }
    my $var_name = $node->{left}{value};
    my $value = $self->evaluate_expression($node->{right});
    my $var = $self->find_variable($var_name);
    my $operator = $node->{operator}{value};
    if ($operator eq '=') {
        $var->{computed_value} = $value;
    } elsif ($operator eq '+=') {
        my $current_value = $var->{computed_value} // $var->{value} // 0;
        $var->{computed_value} = $current_value + $value;
    } elsif ($operator eq '-=') {
        my $current_value = $var->{computed_value} // $var->{value} // 0;
        $var->{computed_value} = $current_value - $value;
    } else {
        die "Unsupported assignment operator: $operator";
    }
}

# Обработка унарной операции (например, i++)
sub handle_unary_operation {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_unary_operation: $node->{operator}{value}\n";
    }
    my $var_name = $node->{operand}{value};
    my $var = $self->find_variable($var_name);
    if ($node->{operator}{value} eq '++') {
        $var->{value} += 1;
    } elsif ($node->{operator}{value} eq '--') {
        $var->{value} -= 1;
    } else {
        die "Unsupported unary operator: $node->{operator}{value}";
    }
}

# Обработка оператора управления (break)
sub handle_control_statement {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_control_statement: $node->{control_type}\n";
    }
    if ($node->{control_type} eq 'break') {
        $self->{break_flag} = 1;
    } else {
        die "Unsupported control statement: $node->{control_type}";
    }
}

# Обработка условного оператора (if)
sub handle_if_statement {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_if_statement\n";
    }
    my $condition = $self->evaluate_expression($node->{condition});
    if ($self->{debug_mode}) {
        warn "Condition result: $condition\n";
    }
    if ($condition) {
        $self->execute_block($node->{body});
    } elsif (@{$node->{else_body}}) {
        $self->execute_block($node->{else_body});
    }
}

# Обработка цикла for
sub handle_for_loop {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_for_loop: $node->{loop_type}\n";
    }
    if ($node->{loop_type} eq 'standard') {
        # Инициализация
        if ($node->{init}) {
            $self->execute_statement($node->{init});
        }
        while (1) {
            # Проверка условия
            my $condition = $node->{condition} ? $self->evaluate_expression($node->{condition}) : 1;
            last unless $condition;
            $self->{break_flag} = 0;
            $self->execute_block($node->{body});
            last if $self->{break_flag} || defined $self->{return_value};
            # Итерация
            if ($node->{iteration}) {
                $self->execute_statement($node->{iteration});
            }
        }
    } elsif ($node->{loop_type} eq 'infinite') {
        while (1) {
            $self->{break_flag} = 0;
            $self->execute_block($node->{body});
            last if $self->{break_flag} || defined $self->{return_value};
        }
    } elsif ($node->{loop_type} eq 'range') {
        my $range_var = $self->evaluate_expression($node->{range});
        my $index_var = $node->{index};
        my $value_var = $node->{value};
        my $new_scope = {};
        for my $i (0..$#$range_var) {
            if ($index_var && $index_var ne '_') {
                $new_scope->{$index_var} = { type => 'int', value => $i };
            }
            if ($value_var) {
                $new_scope->{$value_var} = { type => 'Student', value => $range_var->[$i] };
            }
            push @{$self->{scopes}}, $new_scope;
            $self->execute_block($node->{body});
            pop @{$self->{scopes}};
        }
    } else {
        die "Unsupported for loop type: $node->{loop_type}";
    }
}

# Обработка оператора switch
sub handle_switch_statement {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_switch_statement\n";
    }
    my $switch_value = $self->evaluate_expression($node->{condition});
    if ($self->{debug_mode}) {
        warn "switch_value: $switch_value\n";
    }
    for my $case (@{$node->{cases}}) {
        if ($case->{type} eq 'CaseStatement') {
            my $case_value = $self->evaluate_expression($case->{value});
            if ($self->{debug_mode}) {
                warn "case_value: $case_value\n";
            }
            if ($switch_value eq $case_value) {
                $self->execute_block($case->{body});
                return;
            }
        } elsif ($case->{type} eq 'DefaultStatement') {
            $self->execute_block($case->{body});
            return;
        }
    }
}

# Обработка оператора return
sub handle_return_statement {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_return_statement\n";
    }
    $self->{return_value} = $self->evaluate_expression($node->{expression});
}

# Обработка вызова функции
sub handle_function_call {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_function_call: $node->{name}\n";
    }
    my $package = $node->{package};
    my $name = $node->{name};
    my @args = map { $self->evaluate_expression($_) } @{$node->{args}};

    if ($package && $package eq 'fmt') {
        $self->handle_fmt_function($name, \@args, $node);
        return undef;
    } elsif (!defined $package && ($name eq 'print' || $name eq 'println' || $name eq 'len')) {
        return $self->handle_builtin_function($name, \@args, $node);
    } elsif (!defined $package && $name eq 'append') {
        return $self->handle_append_function(\@args);
    } else {
        my $func = $self->{functions}{$name} or die "Function $name not found";
        my $func_node = $func->{node};
        
        my $new_scope = {};
        for my $i (0..$#{$func->{params}}) {
            my $param_name = $func->{params}[$i]{name};
            my $param_type = $func->{params}[$i]{type};
            $new_scope->{$param_name} = {
                type => $param_type,
                value => $args[$i],
            };
        }
        
        my $prev_function = $self->{current_function};
        $self->{current_function} = $name;
        push @{$self->{scopes}}, $new_scope;
        $self->{return_value} = undef;
        $self->execute_block($func_node->{body});
        my $result = $self->{return_value};
        pop @{$self->{scopes}};
        $self->{current_function} = $prev_function;
        $self->{return_value} = undef;
        return $result;
    }
}

# Обработка функций пакета fmt
sub handle_fmt_function {
    my ($self, $name, $args, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_fmt_function: $name\n";
    }
    if ($name eq 'Print' || $name eq 'Println') {
        my @output = map { $self->format_value($_) } @$args;
        print join(" ", @output), ($name eq 'Println' ? "\n" : "");
    } elsif ($name eq 'Printf') {
        my $format = shift @$args;
        $format = $1 if $format =~ /^"(.*)"$/;
        $format = $self->unescape_string($format);
        my @formatted_args = map { $self->format_value($_) } @$args;
        printf($format, @formatted_args);
    } elsif ($name eq 'Scan') {
        for my $i (0..$#$args) {
            my $arg = $node->{args}[$i];
            my $input = $self->get_input($node, $i);
            if ($arg->{is_by_reference}) {
                my $var_name = $arg->{value};
                my $var = $self->find_variable($var_name);
                $var->{value} = $self->convert_input($input, $var->{type});
            }
        }
    } else {
        die "Unsupported fmt function: $name";
    }
}

# Вспомогательная функция для обработки escape-последовательностей
sub unescape_string {
    my ($self, $string) = @_;
    if ($self->{debug_mode}) {
        warn "unescape_string: $string\n";
    }
    $string =~ s/\\n/\n/g;
    $string =~ s/\\t/\t/g;
    $string =~ s/\\r/\r/g;
    $string =~ s/\\"/"/g;
    $string =~ s/\\\\/\\/g;
    return $string;
}

# Обработка встроенных функций Go
sub handle_builtin_function {
    my ($self, $name, $args, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_builtin_function: $name\n";
    }
    if ($name eq 'print' || $name eq 'println') {
        my @output = map { $self->format_value($_) } @$args;
        print join(" ", @output), ($name eq 'println' ? "\n" : "");
        return undef;
    } elsif ($name eq 'len') {
        my $arg = $args->[0];
        my $arg_type = $self->get_expression_type($node->{args}[0]);
        if ($arg_type eq 'string') {
            $arg = $1 if $arg =~ /^"(.*)"$/;
            return length($arg);
        } elsif ($arg_type =~ /^\[\]/) {
            return scalar(@$arg);
        }
        die "len: argument must be a string or slice, got $arg_type";
    } else {
        die "Unsupported builtin function: $name";
    }
}

# Обработка функции append
sub handle_append_function {
    my ($self, $args) = @_;
    if ($self->{debug_mode}) {
        warn "handle_append_function\n";
    }
    my $slice = $args->[0];
    my $value = $args->[1];
    push @$slice, $value;
    return $slice;
}

# Форматирование значения для вывода
sub format_value {
    my ($self, $value) = @_;
    if ($self->{debug_mode}) {
        warn "format_value\n";
    }
    if (ref($value) eq 'ARRAY') {
        return "[" . join(" ", @$value) . "]";
    }
    if (ref($value) eq 'HASH') {
        my @fields = map { "$_: $value->{$_}" } keys %$value;
        return "{" . join(", ", @fields) . "}";
    }
    if (defined $value && $value =~ /^"(.*)"$/) {
        return $self->unescape_string($1);
    }
    return defined $value ? $value : "";
}

# Получение текущей области видимости
sub current_scope {
    my ($self) = @_;
    if ($self->{debug_mode}) {
        warn "current_scope\n";
    }
    return $self->{scopes}[-1];
}

# Поиск переменной в областях видимости
sub find_variable {
    my ($self, $name) = @_;
    if ($self->{debug_mode}) {
        warn "find_variable: $name\n";
    }
    # Проверяем текущие области видимости, игнорируя переменные с типом 'auto'
    for my $scope (reverse @{$self->{scopes}}) {
        if (exists $scope->{$name} && $scope->{$name}{type} ne 'auto') {
            return $scope->{$name};
        }
    }
    # Проверяем переменные в таблице символов для текущей области
    my $current_scope_name = $self->get_current_scope_name();
    my $variables = $self->{symbol_table}{scopes}{$current_scope_name}{variables} || {};
    if (exists $variables->{$name} && $variables->{$name}{type} ne 'auto') {
        my $var_value = $variables->{$name}{value};
        if (defined $var_value) {
            return { type => $variables->{$name}{type}, value => $var_value };
        }
    }
    # Ищем во вложенных областях
    my $inner_scopes = $self->{symbol_table}{scopes}{$current_scope_name}{inner_scopes} || [];
    for my $inner_scope (@$inner_scopes) {
        my $inner_scope_name = $inner_scope->{name};
        my $inner_variables = $self->{symbol_table}{scopes}{$inner_scope_name}{variables};
        if (exists $inner_variables->{$name} && $inner_variables->{$name}{type} ne 'auto') {
            my $var_value = $inner_variables->{$name}{value};
            if (defined $var_value) {
                return { type => $inner_variables->{$name}{type}, value => $var_value };
            }
        }
    }
    die "Variable $name not found";
}

# Получение имени текущей области видимости
sub get_current_scope_name {
    my ($self) = @_;
    if ($self->{debug_mode}) {
        warn "get_current_scope_name\n";
    }
    return $self->{current_function} // '-Global-';
}

# Вычисление выражения
sub evaluate_expression {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "evaluate_expression: " . ($node->{type} // 'undef') . "\n";
    }
    my $type = $node->{type} // die "Expression type is undefined";

    if ($type eq 'IntLiteral') {
        return $node->{value};
    } elsif ($type eq 'StringLiteral') {
        my $value = $node->{value};
        $value =~ s/^"(.*)"$/$1/;
        return $value;
    } elsif ($type eq 'Identifier') {
        my $var = $self->find_variable($node->{value});
        if (ref($var->{value}) eq 'HASH' && exists $var->{value}{type} && $var->{value}{type} eq 'Expression' && !exists $var->{computed_value}) {
            my $computed_value = $self->evaluate_expression($var->{value}{value});
            $var->{computed_value} = $computed_value;
            return $computed_value;
        }
        return $var->{computed_value} // $var->{value} // die "Variable $node->{value} is not initialized";
    } elsif ($type eq 'BinaryOperation' || $type eq 'RelationalExpression' || $type eq 'LogicalExpression') {
        my $left = $self->evaluate_expression($node->{left});
        my $right = $self->evaluate_expression($node->{right});
        my $op = $node->{operator}{value};
        
        if ($type eq 'BinaryOperation') {
            return $self->evaluate_binary_operation($left, $right, $op, $node);
        } elsif ($type eq 'RelationalExpression') {
            return $self->evaluate_relational_operation($left, $right, $op);
        } elsif ($type eq 'LogicalExpression') {
            return $self->evaluate_logical_operation($left, $right, $op);
        }
    } elsif ($type eq 'FunctionCall') {
        return $self->handle_function_call($node);
    } elsif ($type eq 'FieldAccess') {
        return $self->evaluate_field_access($node);
    } elsif ($type eq 'StructInitialization') {
        return $self->evaluate_struct_initialization($node);
    } elsif ($type eq 'Array') {
        return $self->evaluate_array($node);
    } else {
        die "Unsupported expression type: $type";
    }
}

# Обработка доступа к полям структуры
sub evaluate_field_access {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "evaluate_field_access: $node->{object}{value}.$node->{field}{value}\n";
    }
    my $object = $self->find_variable($node->{object}{value});
    my $field_name = $node->{field}{value};
    return $object->{value}{$field_name} // die "Field $field_name not found in $node->{object}{value}";
}

# Обработка инициализации структуры
sub evaluate_struct_initialization {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "evaluate_struct_initialization\n";
    }
    my $struct_name = $node->{struct_name};
    my $struct_def = $self->{scopes}[0]->{$struct_name} // die "Struct $struct_name not found";
    my $instance = {};
    
    for my $field (@{$node->{fields}}) {
        my $field_name = $field->{name};
        my $field_value = $self->evaluate_expression($field->{value});
        $instance->{$field_name} = $field_value;
    }
    
    return $instance;
}

# Обработка инициализации массива
sub evaluate_array {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "evaluate_array\n";
    }
    my @elements = map { $self->evaluate_expression($_) } @{$node->{elements}};
    return \@elements;
}

# Арифметические операции
sub evaluate_binary_operation {
    my ($self, $left, $right, $op, $node) = @_;
    if ($self->{debug_mode}) {
        warn "evaluate_binary_operation: $op\n";
    }
    if ($op eq '+') { return $left + $right; }
    if ($op eq '-') { return $left - $right; }
    if ($op eq '*') { return $left * $right; }
    if ($op eq '/') {
        die "Division by zero" if $right == 0;
        return $left / $right;
    }
    die "Unsupported binary operator: $op";
}

# Реляционные операции
sub evaluate_relational_operation {
    my ($self, $left, $right, $op) = @_;
    if ($self->{debug_mode}) {
        warn "evaluate_relational_operation: $op\n";
    }
    if ($op eq '==') { return $left eq $right ? 1 : 0; }
    if ($op eq '!=') { return $left ne $right ? 1 : 0; }
    if ($op eq '<=') { return $left <= $right ? 1 : 0; }
    if ($op eq '>=') { return $left >= $right ? 1 : 0; }
    die "Unsupported relational operator: $op";
}

# Логические операции
sub evaluate_logical_operation {
    my ($self, $left, $right, $op) = @_;
    if ($self->{debug_mode}) {
        warn "evaluate_logical_operation: $op\n";
    }
    if ($op eq '||') {
        return ($left == 1 || $right == 1) ? 1 : 0;
    } elsif ($op eq '&&') {
        return ($left == 1 && $right == 1) ? 1 : 0;
    }
    die "Unsupported logical operator: $op";
}

# Получение типа выражения
sub get_expression_type {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "get_expression_type: $node->{type}\n";
    }
    if ($node->{type} eq 'BinaryOperation') {
        return $self->get_expression_type($node->{left});
    } elsif ($node->{type} eq 'StringLiteral') {
        return 'string';
    } elsif ($node->{type} eq 'IntLiteral') {
        return 'int';
    } elsif ($node->{type} eq 'RelationalExpression' || $node->{type} eq 'LogicalExpression') {
        return 'bool';
    } elsif ($node->{type} eq 'Identifier') {
        return $self->find_variable($node->{value})->{type};
    } elsif ($node->{type} eq 'FunctionCall') {
        return $self->{symbol_table}{functions}{$node->{name}}{return_types}[0] // 'void';
    } elsif ($node->{type} eq 'FieldAccess') {
        my $object = $self->find_variable($node->{object}{value});
        my $struct_def = $self->{scopes}[0]->{$object->{type}} // die "Struct $object->{type} not found";
        return $struct_def->{fields}{$node->{field}{value}} // die "Field $node->{field}{value} not found";
    } elsif ($node->{type} eq 'StructInitialization') {
        return $node->{struct_name} // 'Student';
    } elsif ($node->{type} eq 'Array') {
        return "[]$node->{array_type}";
    }
    die "Cannot determine type for expression: $node->{type}";
}

# Получение значения по умолчанию
sub default_value {
    my ($self, $type) = @_;
    if ($self->{debug_mode}) {
        warn "default_value: $type\n";
    }
    if ($type eq 'float64') { return 0.0; }
    if ($type eq 'string') { return ""; }
    if ($type eq 'int') { return 0; }
    return undef;
}

# Конвертация входных данных
sub convert_input {
    my ($self, $input, $type) = @_;
    if ($self->{debug_mode}) {
        warn "convert_input: type=$type, input=" . (defined $input ? $input : 'undef') . "\n";
    }

    die "Input is undefined" unless defined $input;
    die "Type is undefined" unless defined $type;

    if ($type eq 'float64') {
        if ($input =~ /^-?\d*\.?\d+$/ || $input =~ /^-?\d+$/) {
            return 0.0 + $input;
        }
        die "Invalid input for float64: '$input' is not a number";
    } elsif ($type eq 'string') {
        return $input;
    } elsif ($type eq 'int') {
        if ($input =~ /^-?\d+$/) {
            return int($input);
        }
        die "Invalid input for int: '$input' is not an integer";
    }
    die "Unsupported type for input conversion: '$type'";
}

# Получение ввода для fmt.Scan
sub get_input {
    my ($self, $node, $arg_index) = @_;
    if ($self->{debug_mode}) {
        warn "get_input\n";
    }
    if (@{$self->{input_buffer}}) {
        return shift @{$self->{input_buffer}};
    }
    my $input = <STDIN>;
    chomp $input;
    return $input;
}

1;
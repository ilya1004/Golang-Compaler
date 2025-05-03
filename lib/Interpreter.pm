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
        debug_mode => $debug_mode // 0, # Режим отладки (по умолчанию выключен)
    };
    bless $self, $class;
    $self->initialize();
    return $self;
}

# Инициализация: загрузка функций и глобальных констант
sub initialize {
    my ($self) = @_;
    if ($self->{debug_mode}) {
        warn "initialize\n";
    }
    my $global_scope = {};
    
    # Загрузка глобальных констант из таблицы символов
    my $global_symbols = $self->{symbol_table}{scopes}{'-Global-'};
    for my $const (keys %{$global_symbols->{constants}}) {
        $global_scope->{$const} = {
            type => $global_symbols->{constants}{$const}{type},
            value => $global_symbols->{constants}{$const}{value},
        };
    }
    
    # Загрузка функций из таблицы символов
    while (my ($func_name, $func_data) = each %{$self->{symbol_table}{functions}}) {
        $self->{functions}{$func_name} = $func_data;
        $self->{functions}{$func_name}{node} = $self->find_function_node($func_name);
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
    push @{$self->{scopes}}, {}; # Новая область для main
    $self->execute_block($main_node->{body});
    pop @{$self->{scopes}};
    $self->{current_function} = undef;
}

# Выполнение блока операторов (например, тела функции)
sub execute_block {
    my ($self, $block) = @_;
    if ($self->{debug_mode}) {
        warn "execute_block\n";
    }
    for my $statement (@$block) {
        last if defined $self->{return_value}; # Прерываем выполнение при return
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
    $self->current_scope()->{$var_name} = {
        type => $var_type,
        value => $self->default_value($var_type),
    };
}

# Обработка короткого объявления переменной (:=)
sub handle_short_variable_declaration {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_short_variable_declaration\n";
    }
    my $var_name = $node->{nodes}[0]{Text};
    my $value = $self->evaluate_expression($node->{nodes}[2]{value});
    
    # Получение типа из таблицы символов
    my $scope_name = $self->get_current_scope_name();
    
    my $var_type = $self->{symbol_table}{scopes}{$scope_name}{variables}{$var_name}{type}
        or die "Type for $var_name not found in symbol table at scope $scope_name";
    
    $self->current_scope()->{$var_name} = {
        type => $var_type,
        value => $value,
    };
}

# Обработка условного оператора (if)
sub handle_if_statement {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_if_statement\n";
    }
    my $condition = $self->evaluate_expression($node->{condition});
    if ($condition) {
        $self->execute_block($node->{body});
    } elsif (@{$node->{else_body}}) {
        $self->execute_block($node->{else_body});
    }
}

# Обработка оператора switch
sub handle_switch_statement {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "handle_switch_statement\n";
    }
    my $switch_value = $self->evaluate_expression($node->{condition});
    for my $case (@{$node->{cases}}) {
        if ($case->{type} eq 'CaseStatement') {
            my $case_value = $self->evaluate_expression($node->{value});
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
        return undef; # Функции fmt не возвращают значений в данном контексте
    } elsif (!defined $package && ($name eq 'print' || $name eq 'println' || $name eq 'len')) {
        return $self->handle_builtin_function($name, \@args, $node);
    } else {
        my $func = $self->{functions}{$name} or die "Function $name not found";
        my $func_node = $func->{node};
        
        # Создаем новую область видимости
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
        # Удаляем кавычки из формата, если это строковый литерал
        $format = $1 if $format =~ /^"(.*)"$/;
        my @formatted_args = map { $self->format_value($_) } @$args;
        printf($format, @formatted_args);
    } elsif ($name eq 'Scan') {
        for my $i (0..$#$args) {
            my $arg = $node->{args}[$i]; # Используем исходный узел для получения имени переменной
            my $input = $self->get_input($node, $i);
            if ($arg->{is_by_reference}) {
                my $var_name = $arg->{value};
                my $var = $self->find_variable($var_name);
                $var->{value} = $self->convert_input($input, $var->{type});
                # Выводим введенное значение сразу после приглашения
                print "$input\n";
            }
        }
    } else {
        die "Unsupported fmt function: $name";
    }
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
        # Проверяем, что аргумент является строкой
        my $arg_type = $self->get_expression_type($node->{args}[0]);
        die "len: argument must be a string, got $arg_type" unless $arg_type eq 'string';
        # Удаляем кавычки из строкового значения, если они есть
        $arg = $1 if $arg =~ /^"(.*)"$/;
        # Возвращаем длину строки
        return length($arg);
    } else {
        die "Unsupported builtin function: $name";
    }
}

# Форматирование значения для вывода
sub format_value {
    my ($self, $value) = @_;
    if ($self->{debug_mode}) {
        warn "format_value\n";
    }
    if (defined $value && $value =~ /^"(.*)"$/) {
        return $1; # Удаляем кавычки из строкового литерала
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
    for my $scope (reverse @{$self->{scopes}}) {
        return $scope->{$name} if exists $scope->{$name};
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
        warn "evaluate_expression: $node->{type}\n";
    }
    my $type = $node->{type};

    if ($type eq 'IntLiteral' || $type eq 'StringLiteral') {
        return $node->{value};
    } elsif ($type eq 'Identifier') {
        my $var = $self->find_variable($node->{value});
        return $var->{value} // die "Variable $node->{value} is not initialized";
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
    } else {
        die "Unsupported expression type: $type";
    }
}

# Арифметические операции
sub evaluate_binary_operation {
    my ($self, $left, $right, $op, $node) = @_;
    if ($self->{debug_mode}) {
        warn "evaluate_binary_operation: $op\n";
    }
    my $result_type = $self->get_expression_type($node);
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

# Получение типа выражения из таблицы символов
sub get_expression_type {
    my ($self, $node) = @_;
    if ($self->{debug_mode}) {
        warn "get_expression_type: $node->{type}\n";
    }
    if ($node->{type} eq 'BinaryOperation') {
        # Для бинарных операций предполагаем тип левого операнда
        return $self->get_expression_type($node->{left});
    } elsif ($node->{type} eq 'StringLiteral') {
        return 'string';
    } elsif ($node->{type} eq 'IntLiteral') {
        return 'int';
    } elsif ($node->{type} eq 'RelationalExpression' || $node->{type} eq 'LogicalExpression') {
        return 'bool';
    } elsif ($node->{type} eq 'Identifier') {
        return $self->find_variable($node->{value})->{type};
    }
    die "Cannot determine type for expression: $node->{type}";
}

# Получение значения по умолчанию для типа
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

# Конвертация входных данных в нужный тип
sub convert_input {
    my ($self, $input, $type) = @_;
    if ($self->{debug_mode}) {
        warn "convert_input: $type\n";
    }
    if ($type eq 'float64') {
        return 0.0 + $input; # Преобразование в число
    } elsif ($type eq 'string') {
        return $input;
    } elsif ($type eq 'int') {
        return int($input);
    }
    die "Unsupported type for input conversion: $type";
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
    # Если буфер пуст, запрашиваем ввод без лишнего приглашения
    my $input = <STDIN>;
    chomp $input;
    return $input;
}

1;
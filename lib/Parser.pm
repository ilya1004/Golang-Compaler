package Parser;

use strict;
use warnings;
use Data::Dumper;

sub new {
    my ($class, $tokens) = @_;
    return bless {
        tokens => $tokens,       # Список токенов
        pos => 0,                # Текущая позиция в списке токенов
        token_counter => 0,      # Счетчик порядковых номеров токенов
        symbol_table => {
            scopes => {
                '-Global-' => {
                    constants => {},
                    variables => {},
                }
            },
            types => {}
        },
        imports => [],            # Список импортов
        current_scope => "-Global-"
    }, $class;
}

# Возвращает текущий токен
sub current_token {
    my ($self) = @_;
    return $self->{tokens}->[$self->{pos}];
}

sub next_token {
    my ($self) = @_;
    return $self->{tokens}->[$self->{pos} + 1];
}

# Переход к следующему токену
sub consume_token {
    my ($self) = @_;
    $self->{pos}++ if $self->{pos} < @{$self->{tokens}};
}

# Возвращает порядковый номер токена и увеличивает счетчик
sub get_next_token_pos {
    my ($self) = @_;
    my $pos = $self->{token_counter};
    $self->{token_counter}++;
    return $pos;
}

# Парсинг package
sub parse_package {
    my ($self) = @_;
    my @nodes;

    my $token = $self->current_token();
    if ($token->{Name} eq 'package') {
        push @nodes, {
            Name => $token->{Name},
            Text => $token->{Text},
            Pos => $self->get_next_token_pos()
        };
        $self->consume_token();

        my $ident = $self->current_token();
        if ($ident->{Class} eq 'identifier') {
            push @nodes, {
                Name => $ident->{Name},
                Text => $ident->{Text},
                Pos => $self->get_next_token_pos() 
            };
            $self->consume_token();
        } else {
            die "Ожидался идентификатор после 'package'";
        }

        my $semicolon = $self->current_token();
        if ($semicolon->{Name} eq 'semicolon') {
            push @nodes, {
                Name => $semicolon->{Name},
                Text => $semicolon->{Text},
                Pos => $self->get_next_token_pos()
            };
            $self->consume_token();
        } else {
            die "Ожидалась ';' после объявления пакета";
        }
    }
    return { type => 'PackageDeclaration', nodes => \@nodes };
}

# Парсинг import
sub parse_import {
    my ($self) = @_;
    print "parse_import\n";
    my @nodes;
    my @imports;
    my @imports_names;

    my $token = $self->current_token();
    if ($token->{Name} eq 'import') {
        push @nodes, { 
            Name => $token->{Name}, 
            Text => $token->{Text}, 
            Pos => $self->get_next_token_pos() 
            };
        $self->consume_token();

        # Проверяем, есть ли скобки для множественного импорта
        my $has_paren = 0;
        my $next_token = $self->current_token();
        if ($next_token->{Name} eq 'l_paren') {
            $has_paren = 1;
            push @nodes, { 
                Name => $next_token->{Name}, 
                Text => $next_token->{Text}, 
                Pos => $self->get_next_token_pos() 
                };
            $self->consume_token();
        }

        # Парсим импорты
        while ($self->current_token()->{Name} eq 'string') {
            my $import_token = $self->current_token();
            $self->consume_token();

            # Точка с запятой после импорта
            my $semicolon = $self->current_token();
            if ($semicolon->{Name} eq 'semicolon') {
                push @imports, {
                    package   => { 
                        Name => $import_token->{Name}, 
                        Text => $import_token->{Text}, 
                        Pos => $self->get_next_token_pos() 
                        },
                    semicolon => { 
                        Name => $semicolon->{Name}, 
                        Text => $semicolon->{Text}, 
                        Pos => $self->get_next_token_pos() 
                        }
                };

                # Обрабатываем имя пакета
                my $package_name = $import_token->{Text};
                $package_name =~ s/^"|"$//g;  # Удаляем кавычки в начале и конце строки
                push @imports_names, {
                    Package => {
                        Name => $package_name,
                        Pos => $self->{token_counter} - 2
                    },
                };

                $self->consume_token();
            } else {
                die "Ожидалась ';' после импортируемого пути";
            }

            # Если это одиночный импорт (без скобок), выходим из цикла
            last unless $has_paren;
        }

        # Если были скобки, проверяем закрывающую скобку
        if ($has_paren) {
            my $r_paren = $self->current_token();
            if ($r_paren->{Name} eq 'r_paren') {
                push @nodes, { 
                    Name => $r_paren->{Name}, 
                    Text => $r_paren->{Text}, 
                    Pos => $self->get_next_token_pos() 
                    };
                $self->consume_token();
            } else {
                die "Ожидалась ')' после списка импортов";
            }
        }

        # Точка с запятой после импорта (если есть)
        my $semicolon = $self->current_token();
        if ($semicolon->{Name} eq 'semicolon') {
            push @nodes, { 
                Name => $semicolon->{Name}, 
                Text => $semicolon->{Text}, 
                Pos => $self->get_next_token_pos() 
                };
            $self->consume_token();
        }

        # Сохраняем импорты в поле объекта
        push @{$self->{imports}}, @imports_names;
    }
    return { type => 'ImportDeclaration', nodes => \@nodes, imports => \@imports };
}

# Парсинг объявления типа
sub parse_type_declaration {
    my ($self) = @_;
    my @nodes;

    # Ключевые слова
    my @keywords = (
        { Name => "bool",        Regex => "bool",        Class => "keyword" },
        { Name => "string",      Regex => "string",      Class => "keyword" },
        { Name => "int",         Regex => "int",         Class => "keyword" },
        { Name => "int8",        Regex => "int8",        Class => "keyword" },
        { Name => "int16",       Regex => "int16",       Class => "keyword" },
        { Name => "int32",       Regex => "int32",       Class => "keyword" },
        { Name => "int64",       Regex => "int64",       Class => "keyword" },
        { Name => "uint",        Regex => "uint",        Class => "keyword" },
        { Name => "uint8",       Regex => "uint8",       Class => "keyword" },
        { Name => "uint16",      Regex => "uint16",      Class => "keyword" },
        { Name => "uint32",      Regex => "uint32",      Class => "keyword" },
        { Name => "uint64",      Regex => "uint64",      Class => "keyword" },
        { Name => "float32",     Regex => "float32",     Class => "keyword" },
        { Name => "float64",     Regex => "float64",     Class => "keyword" },
    );

    my $type_token = $self->current_token();
    if ($type_token->{Name} eq 'type') {
        push @nodes, { 
            Name => $type_token->{Name}, 
            Text => $type_token->{Text}, 
            Pos => $self->get_next_token_pos() 
            };
        $self->consume_token();

        # Имя типа
        my $type_name = $self->current_token();
        if ($type_name->{Class} eq 'identifier') {
            push @nodes, { 
                Name => $type_name->{Name}, 
                Text => $type_name->{Text}, 
                Pos => $self->get_next_token_pos() 
                };
            $self->consume_token();
        } else {
            die "Ожидалось имя типа после 'type'";
        }

        # Ключевое слово struct
        my $struct_token = $self->current_token();
        if ($struct_token->{Name} eq 'struct') {
            push @nodes, { 
                Name => $struct_token->{Name}, 
                Text => $struct_token->{Text},
                Pos => $self->get_next_token_pos()
                };
            $self->consume_token();
        } else {
            die "Ожидалось ключевое слово 'struct'";
        }

        # Открывающая фигурная скобка
        my $l_brace = $self->current_token();
        if ($l_brace->{Name} eq 'l_brace') {
            push @nodes, {
                Name => $l_brace->{Name}, 
                Text => $l_brace->{Text}, 
                Pos => $self->get_next_token_pos() 
                };
            $self->consume_token();
        } else {
            die "Ожидалась '{' после 'struct'";
        }

        # Поля структуры
        my @fields;
        while ($self->current_token()->{Name} ne 'r_brace') {
            my $field_name = $self->current_token();
            if ($field_name->{Class} eq 'identifier') {
                $self->consume_token(); # Переход к типу поля

                my $field_type = $self->current_token();
                my $is_keyword = 0;

                # Проверяем, является ли тип ключевым словом
                foreach my $keyword (@keywords) {
                    if ($field_type->{Name} eq $keyword->{Name}) {
                        $is_keyword = 1;
                        last;
                    }
                }

                if ($is_keyword || $field_type->{Class} eq 'identifier') {
                    $self->consume_token(); # Переход к точке с запятой

                    # Точка с запятой после поля
                    my $semicolon = $self->current_token();
                    if ($semicolon->{Name} eq 'semicolon') {
                        push @fields, {
                            field_name => { 
                                Name => $field_name->{Name}, 
                                Text => $field_name->{Text}, 
                                Pos => $self->get_next_token_pos() 
                                },
                            field_type => { 
                                Name => $field_type->{Name}, 
                                Text => $field_type->{Text}, 
                                Pos => $self->get_next_token_pos() 
                                },
                            semicolon  => { 
                                Name => $semicolon->{Name}, 
                                Text => $semicolon->{Text}, 
                                Pos => $self->get_next_token_pos() 
                                }
                        };

                        # Добавляем поле в таблицу символов (без знаков препинания)
                        $self->{symbol_table}{types}{$type_name->{Text}}{fields}{$field_name->{Text}} = $field_type->{Text};
                        $self->consume_token();
                    } else {
                        die "Ожидалась ';' после объявления поля";
                    }
                } else {
                    die "Ожидался тип поля (ключевое слово или идентификатор)";
                }
            } else {
                die "Ожидалось имя поля";
            }
        }

        # Закрывающая фигурная скобка
        my $r_brace = $self->current_token();
        if ($r_brace->{Name} eq 'r_brace') {
            push @nodes, { Name => $r_brace->{Name}, Text => $r_brace->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась '}' после полей структуры";
        }

        # Точка с запятой после закрывающей фигурной скобки
        my $semicolon = $self->current_token();
        if ($semicolon->{Name} eq 'semicolon') {
            push @nodes, { Name => $semicolon->{Name}, Text => $semicolon->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась ';' после '}'";
        }

        return { type => 'TypeDeclaration', name => $type_name->{Text}, fields => \@fields, nodes => \@nodes };
    }
    return undef;
}

# Парсинг объявления переменной
sub parse_variable_declaration {
    my ($self) = @_;
    print "parse_variable_declaration\n";
    my @nodes;

    # Определяем, используется ли 'var' или короткое объявление (:=)
    my $is_var_declaration = $self->current_token()->{Name} eq 'var';
    my $is_short_declaration = $self->current_token()->{Class} eq 'identifier';

    if ($is_var_declaration) {
        # Токен 'var'
        my $var_token = $self->current_token();
        push @nodes, { 
            Name => $var_token->{Name}, 
            Text => $var_token->{Text}, 
            Pos => $self->get_next_token_pos() 
        };
        $self->consume_token();
    } elsif (!$is_short_declaration) {
        die "Ожидалось ключевое слово 'var' или короткое объявление (:=)";
    }

    # Список переменных
    my @var_names;
    while (1) {
        my $var_name = $self->current_token();
        if ($var_name->{Class} eq 'identifier') {
            push @var_names, $var_name;
            push @nodes, { Name => $var_name->{Name}, Text => $var_name->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалось имя переменной";
        }

        # Проверяем, есть ли следующая переменная (через запятую)
        my $comma = $self->current_token();
        if ($comma->{Name} eq 'comma') {
            push @nodes, { Name => $comma->{Name}, Text => $comma->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            last;  # Завершаем цикл, если запятая отсутствует
        }
    }

    my $var_type;
    if ($is_var_declaration) {
        $var_type = $self->parse_type();
        if (!defined($var_type)) {
            $var_type = "auto";
        }
        push @nodes, { Name => 'Type', Text => $var_type, Pos => $self->get_next_token_pos() };
    }

    my $assign_token = $self->current_token();

    # Проверяем корректность оператора присваивания
    if ($is_var_declaration && $assign_token->{Name} eq 'declaration') {
        die "Некорректный оператор ':=' в декларации с 'var'; ожидался '='";
    } elsif (!$is_var_declaration && $assign_token->{Name} eq 'assignment') {
        die "Некорректный оператор '=' в короткой декларации; ожидался ':='";
    }

    if ($assign_token->{Name} eq 'assignment' || $assign_token->{Name} eq 'declaration') {
        push @nodes, { Name => $assign_token->{Name}, Text => $assign_token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();

        my $next_token = $self->next_token();

        if ($next_token->{Name} eq 'l_brace') {
            my $struct_initialization = $self->parse_struct_initialization();
            
            delete $struct_initialization->{nodes};
            
            if ($struct_initialization->{type} eq 'StructInitialization') {
                $var_type = $struct_initialization->{struct_name};
            }

            push @nodes, { type => 'StructInitialization', value => $struct_initialization };
            
            my $scope = $self->{current_scope} || '-Global-';
            foreach my $var_name (@var_names) {
                $self->{symbol_table}{scopes}{$scope}{variables}{$var_name->{Text}} = {
                    type => $var_type ? $var_type : 'auto',
                    pos => $self->{token_counter},
                    value => $struct_initialization
                };
            }
        } else {
            # Парсим обычное выражение после оператора присваивания
            my $expr = $self->parse_expression();
            push @nodes, { type => 'Expression', value => $expr };
            
            if ($expr->{type} eq 'FunctionCall') {
                delete $expr->{nodes};
            }

            if ($expr->{type} eq 'Array') {
                delete $expr->{nodes};
                foreach my $element (@{$expr->{elements}}) {
                    delete $element->{nodes};
                }
            }
            
            if ($expr->{type} eq 'Array' && $expr->{array_type}) {
                $var_type = "[]$expr->{array_type}";
            }
        
            # Добавляем переменные в таблицу символов
            my $scope = $self->{current_scope} || '-Global-';
            foreach my $var_name (@var_names) {
                $self->{symbol_table}{scopes}{$scope}{variables}{$var_name->{Text}} = {
                    type => $var_type ? $var_type : 'auto',
                    pos => $self->{token_counter},
                    value => $expr
                };
            }
        }
    } elsif ($is_var_declaration) {
        my $scope = $self->{current_scope} || '-Global-';
        foreach my $var_name (@var_names) {
            $self->{symbol_table}{scopes}{$scope}{variables}{$var_name->{Text}} = {
                type => $var_type,
                pos => $self->{token_counter}
            };
        }
    } else {
        die "Ожидалось присвоение значения для короткого объявления";
    }

    my $semicolon = $self->current_token();
    if ($semicolon->{Name} eq 'semicolon') {
        push @nodes, { Name => $semicolon->{Name}, Text => $semicolon->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } elsif ($semicolon->{Name} ne 'EOF') {
        die "Ожидалась ';' после объявления переменной";
    }

    my $node_type = $is_var_declaration ? 'VariableDeclaration' : 'ShortVariableDeclaration';
    return { type => $node_type, nodes => \@nodes };
}

# Парсинг объявления структуры
sub parse_struct_initialization {
    my ($self) = @_;
    print "parse_struct_initialization\n";
    my @nodes;

    my $struct_name = $self->current_token();
    my $struct_name_str;
    if ($struct_name->{Class} eq 'identifier') {
        $struct_name_str = $struct_name->{Text};
        $self->consume_token();
    } 

    # Открывающая фигурная скобка
    my $l_brace = $self->current_token();
    if ($l_brace->{Name} eq 'l_brace') {
        push @nodes, { Name => $l_brace->{Name}, Text => $l_brace->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась '{' для начала инициализации структуры";
    }

    # Парсим поля структуры
    my @fields;
    while ($self->current_token()->{Name} ne 'r_brace') {
        # Парсим имя поля
        my $field_name = $self->current_token();
        if ($field_name->{Class} eq 'identifier') {
            push @nodes, { Name => $field_name->{Name}, Text => $field_name->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалось имя поля структуры";
        }

        # Двоеточие после имени поля
        my $colon = $self->current_token();
        if ($colon->{Name} eq 'colon') {
            push @nodes, { Name => $colon->{Name}, Text => $colon->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалось ':' после имени поля";
        }

        # Парсим значение поля
        my $field_value = $self->parse_expression();
        push @fields, { name => $field_name->{Text}, value => $field_value };

        # Проверяем, есть ли следующее поле (через запятую)
        my $comma = $self->current_token();
        if ($comma->{Name} eq 'comma') {
            push @nodes, { Name => $comma->{Name}, Text => $comma->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        }
    }

    # Закрывающая фигурная скобка
    my $r_brace = $self->current_token();
    if ($r_brace->{Name} eq 'r_brace') {
        push @nodes, { Name => $r_brace->{Name}, Text => $r_brace->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась '}' для завершения инициализации структуры";
    }

    return {
        type => 'StructInitialization',
        struct_name => $struct_name_str,
        fields => \@fields,
        nodes => \@nodes
    };
}

# Парсинг объявления константы
sub parse_const_declaration {
    my ($self) = @_;
    print "parse_const_declaration\n";
    my @nodes;

    # Токен 'const'
    my $const_token = $self->current_token();
    if ($const_token->{Name} eq 'const') {
        push @nodes, { Name => $const_token->{Name}, Text => $const_token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалось ключевое слово 'const'";
    }

    # Имя константы
    my $const_name = $self->current_token();
    if ($const_name->{Class} eq 'identifier') {
        push @nodes, { Name => $const_name->{Name}, Text => $const_name->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалось имя константы";
    }

    # Проверяем, указан ли тип
    my $const_type;
    my $next_token = $self->current_token();
    if ($next_token->{Class} eq 'keyword' || $next_token->{Class} eq 'identifier') {
        $const_type = $self->parse_type();
        if ($const_type) {
            push @nodes, { Name => 'Type', Text => $const_type, Pos => $self->get_next_token_pos() };
        }
    }

    # Оператор присваивания
    my $assign_token = $self->current_token();
    if ($assign_token->{Name} eq 'assignment') {
        push @nodes, { Name => $assign_token->{Name}, Text => $assign_token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидался оператор присваивания '='";
    }

    # Значение константы
    my $const_value = $self->current_token();
    if ($const_value->{Class} eq 'constant') {
        push @nodes, { Name => $const_value->{Name}, Text => $const_value->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалось значение константы (строка или число)";
    }

    # Точка с запятой после объявления (если она есть)
    my $semicolon = $self->current_token();
    if ($semicolon->{Name} eq 'semicolon') {
        push @nodes, { Name => $semicolon->{Name}, Text => $semicolon->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } elsif ($semicolon->{Name} ne 'EOF' && $semicolon->{Line} == $const_name->{Line}) {
        die "Ожидалась ';' после объявления константы";
    }

    # Добавляем константу в таблицу символов
    my $scope = $self->{current_scope} || '-Global-';
    $self->{symbol_table}{scopes}{$scope}{constants}{$const_name->{Text}} = {
        type => $const_type || 'auto',  # Тип указан явно или auto
        value => $const_value->{Text},
        pos => $self->{token_counter}  # Позиция в коде
    };

    return { type => 'ConstDeclaration', nodes => \@nodes };
}

# Парсинг функции
sub parse_function {
    my ($self) = @_;
    print "parse_function\n";
    my @nodes;

    my $func_token = $self->current_token();
    if ($func_token->{Name} eq 'func') {
        push @nodes, { Name => $func_token->{Name}, Text => $func_token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();

        # Имя функции
        my $func_name = $self->current_token();
        if ($func_name->{Class} eq 'identifier') {
            push @nodes, { Name => $func_name->{Name}, Text => $func_name->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалось имя функции после 'func'";
        }

        # Устанавливаем текущую область видимости
        $self->{current_scope} = $func_name->{Text};

        # Открывающая скобка для параметров
        my $l_paren = $self->current_token();
        if ($l_paren->{Name} eq 'l_paren') {
            push @nodes, { Name => $l_paren->{Name}, Text => $l_paren->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась '(' после имени функции";
        }

        # Парсинг параметров функции
        my @params;
        my $param_pos = 0;  # Счетчик позиции параметра
        while ($self->current_token()->{Name} ne 'r_paren') {
            # Имена параметров
            my @param_names;
            while ($self->current_token()->{Class} eq 'identifier') {
                push @param_names, $self->current_token();
                $self->consume_token();

                # Запятая между именами параметров (если есть)
                my $comma = $self->current_token();
                if ($comma->{Name} eq 'comma') {
                    $self->consume_token();
                } else {
                    last;
                }
            }

            # Тип параметра
            my $param_type = $self->parse_type();
            if (!$param_type) {
                die "Ожидался тип параметра";
            }

            # Добавляем параметры в таблицу символов с областью видимости, привязанной к функции
            foreach my $param_name (@param_names) {
                $self->{symbol_table}{scopes}{$func_name->{Text}}{variables}{$param_name->{Text}} = {
                    type => $param_type,
                    pos => $self->{token_counter}
                };

                push @params, {
                    param_name => { Name => $param_name->{Name}, Text => $param_name->{Text}, Pos => $self->get_next_token_pos() },
                    param_type => $param_type,
                    param_pos => $param_pos
                };

                $param_pos++;
            }

            my $comma = $self->current_token();
            if ($comma->{Name} eq 'comma') {
                $self->consume_token();
            } elsif ($self->current_token()->{Name} ne 'r_paren') {
                die "Ожидалась ',' или ')' после параметра";
            }
        }

        my $r_paren = $self->current_token();
        if ($r_paren->{Name} eq 'r_paren') {
            push @nodes, { 
                Name => $r_paren->{Name},
                Text => $r_paren->{Text}, 
                Pos => $self->get_next_token_pos() 
            };
            $self->consume_token();
        } else {
            die "Ожидалась ')' после параметров функции";
        }

        my @return_types;
        my $return_token = $self->current_token();
        if ($return_token->{Name} eq 'l_paren') {
            push @nodes, { 
                Name => $return_token->{Name}, 
                Text => $return_token->{Text}, 
                Pos => $self->get_next_token_pos() 
            };
            $self->consume_token();

            while ($self->current_token()->{Name} ne 'r_paren') {
                my $return_type = $self->parse_type();
                if ($return_type) {
                    push @return_types, $return_type;
                } else {
                    die "Ожидался тип возвращаемого значения";
                }

                # Запятая между типами (если есть)
                my $comma = $self->current_token();
                if ($comma->{Name} eq 'comma') {
                    $self->consume_token();
                } elsif ($self->current_token()->{Name} ne 'r_paren') {
                    die "Ожидалась ',' или ')' после типа возвращаемого значения";
                }
            }

            my $r_paren_return = $self->current_token();
            if ($r_paren_return->{Name} eq 'r_paren') {
                push @nodes, { 
                    Name => $r_paren_return->{Name}, 
                    Text => $r_paren_return->{Text}, 
                    Pos => $self->get_next_token_pos() 
                };
                $self->consume_token();
            } else {
                die "Ожидалась ')' после возвращаемых значений";
            }
        } elsif ($return_token->{Class} eq 'keyword' || $return_token->{Class} eq 'identifier' || $return_token->{Name} eq 'l_bracket') {
            # Если возвращаемое значение одно
            my $return_type = $self->parse_type();
            if ($return_type) {
                push @return_types, $return_type;
            } else {
                die "Ожидался тип возвращаемого значения";
            }
        }

        # Записываем сигнатуру функции в таблицу символов
        $self->{symbol_table}{functions}{$func_name->{Text}} = {
            params => [ map { { 
                name => $_->{param_name}{Text}, 
                type => $_->{param_type}, 
                param_pos => $_->{param_pos} 
            } } @params ],
            return_types => \@return_types,
            pos => $func_name->{Pos}
        };

        # Открывающая фигурная скобка для тела функции
        my $l_brace = $self->current_token();
        if ($l_brace->{Name} eq 'l_brace') {
            push @nodes, { Name => $l_brace->{Name}, Text => $l_brace->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась '{' после объявления функции";
        }

        # Тело функции
        my @body;
        while ($self->current_token()->{Name} ne 'r_brace') {
            my $stmt = $self->parse_statement();
            push @body, $stmt if $stmt;
        }

        # Закрывающая фигурная скобка для тела функции
        my $r_brace = $self->current_token();
        if ($r_brace->{Name} eq 'r_brace') {
            push @nodes, { Name => $r_brace->{Name}, Text => $r_brace->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась '}' после тела функции";
        }

        # Точка с запятой после закрывающей фигурной скобки
        my $semicolon = $self->current_token();
        if ($semicolon->{Name} eq 'semicolon') {
            push @nodes, { Name => $semicolon->{Name}, Text => $semicolon->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась ';' после '}'";
        }

        # Сбрасываем текущую область видимости
        $self->{current_scope} = '-Global-';

        return {
            type => 'FunctionDeclaration',
            name => $func_name->{Text},
            params => \@params,
            return_types => \@return_types,
            body => \@body,
            nodes => \@nodes
        };
    }
    return undef;
}

# Для обработки типов
sub parse_type {
    my ($self) = @_;
    print "parse_type\n";
    my $type_token = $self->current_token();

    my $next_token = $self->next_token();
    if ($next_token->{Name} eq 'declaration' && $next_token->{Text} eq ':=') {
        return undef;
    }

    if ($type_token->{Name} eq 'l_bracket') {
        $self->consume_token();
        
        # Проверяем, есть ли закрывающая скобка
        my $close_bracket = $self->current_token();
        if ($close_bracket->{Name} eq 'r_bracket') {
            $self->consume_token();
            
            my $array_type = $self->parse_type();
            if (!$array_type) {
                die "Ожидался тип элемента массива";
            }
            
            return "[]$array_type";
        } else {
            die "Ожидалась ']' после типа массива";
        }
    }

    # Обработка обычных типов (int, float64, string и т.д.)
    if ($type_token->{Class} eq 'keyword' || $type_token->{Class} eq 'identifier') {
        my $type_name = $type_token->{Text};
        $self->consume_token();
        return $type_name;
    }

    return undef;
}

# Парсинг выражения (расширен для поддержки массивов и структур)
sub parse_expression {
    my ($self) = @_;
    print "parse_expression\n";
    my @nodes;

    # Проверяем, является ли текущий токен началом массива или структуры
    my $current_token = $self->current_token();
    if ($current_token->{Name} eq 'l_bracket') {
        # Парсим массив
        return $self->parse_array();
    } elsif ($current_token->{Name} eq 'l_brace') {
        # Парсим структуру
        return $self->parse_struct();
    } else {
        # Парсим выражение с операторами
        return $self->parse_assignment_expression();
    }
}

# Парсинг массива
sub parse_array {
    my ($self) = @_;
    print "parse_array\n";
    my @nodes;

    # Открывающая квадратная скобка
    my $l_bracket = $self->current_token();
    if ($l_bracket->{Name} eq 'l_bracket') {
        push @nodes, { Name => $l_bracket->{Name}, Text => $l_bracket->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась '[' для начала массива";
    }

    # Закрывающая квадратная скобка
    my $r_bracket = $self->current_token();
    if ($r_bracket->{Name} eq 'r_bracket') {
        push @nodes, { Name => $r_bracket->{Name}, Text => $r_bracket->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась ']' для завершения типа массива";
    }

    # Тип массива (например, 'Student')
    my $array_type = $self->current_token();
    if ($array_type->{Class} eq 'keyword' || $array_type->{Class} eq 'identifier') {
        push @nodes, { Name => 'ArrayType', Text => $array_type->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидался тип массива (например, 'Student')";
    }

    # Открывающая фигурная скобка для инициализации массива
    my $l_brace = $self->current_token();
    if ($l_brace->{Name} eq 'l_brace') {
        push @nodes, { Name => $l_brace->{Name}, Text => $l_brace->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась '{' для начала инициализации массива";
    }

    # Парсим элементы массива
    my @elements;
    while ($self->current_token()->{Name} ne 'r_brace') {
        # Если элемент массива — структура
        if ($self->current_token()->{Name} eq 'l_brace') {
            my $struct = $self->parse_struct_initialization();
            push @elements, $struct;
        } else {
            # Если элемент массива — простое выражение
            my $element = $self->parse_expression();
            push @elements, $element;
        }

        # Проверяем, есть ли следующий элемент (через запятую)
        my $comma = $self->current_token();
        if ($comma->{Name} eq 'comma') {
            push @nodes, { Name => $comma->{Name}, Text => $comma->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        }
    }

    # Закрывающая фигурная скобка для инициализации массива
    my $r_brace = $self->current_token();
    if ($r_brace->{Name} eq 'r_brace') {
        push @nodes, { Name => $r_brace->{Name}, Text => $r_brace->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась '}' для завершения инициализации массива";
    }

    return { 
        type => 'Array',
        array_type => $array_type->{Text},
        elements => \@elements,
        nodes => \@nodes
        };
}

# Парсинг поля структуры
sub parse_struct_field {
    my ($self) = @_;
    print "parse_struct_field\n";
    my @nodes;

    # Имя поля
    my $field_name = $self->current_token();
    if ($field_name->{Class} eq 'identifier') {
        push @nodes, { Name => $field_name->{Name}, Text => $field_name->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалось имя поля структуры";
    }

    # Значение поля
    my $field_value = $self->parse_expression();
    push @nodes, { type => 'FieldValue', value => $field_value };

    return { type => 'StructField', nodes => \@nodes };
}

# Парсинг простого выражения
sub parse_simple_expression {
    my ($self) = @_;
    print "parse_simple_expression\n";
    my @nodes;

    # Парсим первичное выражение (число, строка, идентификатор и т.д.)
    my $primary = $self->parse_primary_expression();
    push @nodes, { type => 'PrimaryExpression', value => $primary };

    return { type => 'SimpleExpression', nodes => \@nodes };
}

# Парсинг литерала структуры
sub parse_struct_literal {
    my ($self, $struct_type) = @_;
    my @nodes;

    # Открывающая фигурная скобка
    my $l_brace = $self->current_token();
    if ($l_brace->{Name} eq 'l_brace') {
        push @nodes, { Name => $l_brace->{Name}, Text => $l_brace->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась '{' для литерала структуры";
    }

    # Поля структуры
    my @fields;
    while ($self->current_token()->{Name} ne 'r_brace') {
        my $field_name = $self->current_token();
        if ($field_name->{Class} eq 'identifier') {
            $self->consume_token(); # Пропускаем имя поля

            # Двоеточие после имени поля
            my $colon = $self->current_token();
            if ($colon->{Name} eq 'colon') {
                # Убираем добавление colon в nodes
                $self->consume_token();
            } else {
                die "Ожидалось ':' после имени поля";
            }

            # Значение поля
            my $field_value = $self->parse_expression();
            push @fields, {
                field_name => { Name => $field_name->{Name}, Text => $field_name->{Text}, Pos => $self->get_next_token_pos() },
                field_value => $field_value,
                colon => { Name => $colon->{Name}, Text => $colon->{Text}, Pos => $self->get_next_token_pos() }
            };

            # Запятая между полями (если есть)
            my $comma = $self->current_token();
            if ($comma->{Name} eq 'comma') {
                push @nodes, { Name => $comma->{Name}, Text => $comma->{Text}, Pos => $self->get_next_token_pos() };
                $self->consume_token();
            } elsif ($self->current_token()->{Name} ne 'r_brace') {
                die "Ожидалась ',' или '}' после значения поля";
            }
        } else {
            die "Ожидалось имя поля в литерале структуры";
        }
    }

    # Закрывающая фигурная скобка
    my $r_brace = $self->current_token();
    if ($r_brace->{Name} eq 'r_brace') {
        push @nodes, { Name => $r_brace->{Name}, Text => $r_brace->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась '}' для завершения литерала структуры";
    }

    # Если тип структуры не был передан, пытаемся определить его из контекста
    # unless ($struct_type) {
    #     $struct_type = $self->{current_struct_type} // 'auto';
    # }

    # Проверяем, существует ли тип структуры в таблице символов
    unless ($self->{symbol_table}{types}{$struct_type}) {
        die "Тип структуры '$struct_type' не найден в таблице символов";
    }

    return {
        type => 'StructLiteral',
        struct_type => $struct_type, # Сохраняем тип структуры
        fields => \@fields,
        nodes => \@nodes
    };
}

# Парсинг оператора return
sub parse_return_statement {
    my ($self) = @_;
    print "parse_return_statement\n";
    my @nodes;

    my $return_token = $self->current_token();
    if ($return_token->{Name} eq 'return') {
        push @nodes, { Name => $return_token->{Name}, Text => $return_token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();

        my $expression = $self->parse_expression();

        my $semicolon = $self->current_token();
        if ($semicolon->{Name} eq 'semicolon') {
            push @nodes, { Name => $semicolon->{Name}, Text => $semicolon->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } elsif ($semicolon->{Line} == $return_token->{Line}) {
            die "Ожидалась ';' после оператора return";
        }

        return { type => 'ReturnStatement', expression => $expression, nodes => \@nodes };
    }
    return undef;
}

# Парсинг оператора (объявление переменной, цикл, условие, вызов функции и т.д.)
sub parse_statement {
    my ($self) = @_;
    print "parse_statement\n";
    my $token = $self->current_token();
    my $next_token = $self->next_token();

    if ($token->{Name} eq 'const') {
        # Объявление константы
        return $self->parse_const_declaration();
    } elsif ($token->{Name} eq 'var' || ($token->{Class} eq 'identifier' && $next_token->{Name} eq 'declaration')) {
        # Объявление переменной
        return $self->parse_variable_declaration();
    } elsif ($token->{Name} eq 'for') {
        # Цикл for
        return $self->parse_for_loop();
    } elsif ($token->{Name} eq 'if') {
        # Условие if
        return $self->parse_if_statement();
    } elsif ($token->{Name} eq 'return') {
        # Оператор return
        return $self->parse_return_statement();
    } elsif ($token->{Name} eq 'switch') {
        # Конструкция switch-case
        return $self->parse_switch_statement();
    } elsif ($token->{Name} eq 'break' || $token->{Name} eq 'continue') {
        # Управляющие ключевые слова break и continue
        return $self->parse_control_statement();
    } else {
        # Выражение (оператор, присваивание и т.д.)
        return $self->parse_expression();
    }
}

# Парсинг ключевых слов break и continue
sub parse_control_statement {
    my ($self) = @_;
    print "parse_control_statement\n";
    my $token = $self->current_token();

    # Определяем тип управляющего ключевого слова
    my $control_type = $token->{Name};

    # Пропускаем ключевое слово
    $self->consume_token();

    # Точка с запятой после управляющего ключевого слова (если есть)
    my $semicolon = $self->current_token();
    if ($semicolon->{Name} eq 'semicolon') {
        $self->consume_token();
    } elsif ($semicolon->{Name} ne 'EOF' && $semicolon->{Line} == $token->{Line}) {
        die "Ожидалась ';' после управляющего ключевого слова";
    }

    # Возвращаем структуру управляющего ключевого слова
    return {
        type => 'ControlStatement',
        control_type => $control_type,  # break или continue
        Pos => $self->get_next_token_pos()  # Позиция в коде
    };
}

sub contains_string {
    my ($self, $search_string) = @_;
    foreach my $item (@{$self->{imports}}) {
        return 1 if $item->{Package}->{Name} eq $search_string;
    }
    return 0;
}

# Парсинг выражения с присваиванием (например, a = b + 1)
sub parse_assignment_expression {
    my ($self) = @_;
    print "parse_assignment_expression\n";
    my $left = $self->parse_additive_expression();
    my $operator = $self->current_token();
    
    if ($operator->{Class} eq 'operator' && 
        ($operator->{Name} eq 'assignment' || 
         $operator->{Name} eq 'plus_assign' || 
         $operator->{Name} eq 'minus_assign' || 
         $operator->{Name} eq 'mul_assign' || 
         $operator->{Name} eq 'div_assign')) {
        # Получаем позицию оператора из текущего токена
        my $operator_pos = $self->get_next_token_pos();
        $self->consume_token();
        my $right = $self->parse_assignment_expression();
        
        # Проверяем, есть ли точка с запятой после выражения
        my $semicolon = $self->current_token();
        my $has_semicolon = 0;
        if ($semicolon->{Name} eq 'semicolon') {
            $self->consume_token();
            $has_semicolon = 1;
        }
        
        return {
            type => 'AssignmentExpression',
            left => $left,
            operator => {
                type => 'Operator',
                value => $operator->{Text},
                Pos => $operator_pos  # Используем позицию текущего токена
            },
            right => $right,
            semicolon => $has_semicolon ? {
                type => 'Punctuation',
                value => $semicolon->{Text},
                Pos => $self->get_next_token_pos()  # Позиция точки с запятой
            } : undef,
        };
    }
    return $left;
}

# Парсинг выражений с операторами сложения и вычитания (например, a + b - c)
sub parse_additive_expression {
    my ($self) = @_;
    print "parse_additive_expression\n";
    my $left = $self->parse_multiplicative_expression();

    while (1) {
        my $operator = $self->current_token();
        if ($operator->{Class} eq 'operator' && 
            ($operator->{Name} eq 'plus' || $operator->{Name} eq 'minus')) {
            $self->consume_token();
            my $operator_pos = $self->get_next_token_pos();  # Позиция оператора
            my $right = $self->parse_multiplicative_expression();
            $left = {
                type => 'BinaryOperation',
                left => $left,
                operator => {
                    type => 'Operator',
                    value => $operator->{Text},
                    Pos => $operator_pos  # Позиция оператора
                },
                right => $right,
            };
        } else {
            last;
        }
    }
    return $left;
}

# Парсинг выражений с операторами умножения и деления (например, a * b / c)
sub parse_multiplicative_expression {
    my ($self) = @_;
    print "parse_multiplicative_expression\n";
    my $left = $self->parse_primary_expression();

    while (1) {
        my $operator = $self->current_token();
        if ($operator->{Class} eq 'operator' && 
            ($operator->{Name} eq 'multiply' || $operator->{Name} eq 'divide')) {
            $self->consume_token();
            my $operator_pos = $self->get_next_token_pos();  # Позиция оператора
            my $right = $self->parse_primary_expression();
            $left = {
                type => 'BinaryOperation',
                left => $left,
                operator => {
                    type => 'Operator',
                    value => $operator->{Text},
                    Pos => $operator_pos  # Позиция оператора
                },
                right => $right,
            };
        } else {
            last;
        }
    }
    return $left;
}

# Парсинг простого выражения (идентификатор, число, вызов функции и т.д.)
sub parse_primary_expression {
    my ($self) = @_;
    print "parse_primary_expression\n";
    my $token = $self->current_token();

    if ($token->{Name} eq 'increment' || $token->{Name} eq 'decrement') {
        my $operator = $token->{Text};
        $self->consume_token();

        my $operand = $self->parse_primary_expression();

        return {
            type => 'UnaryOperation',
            operator => {
                type => 'Operator',
                value => $operator,
                Pos => $self->get_next_token_pos()
            },
            operand => $operand,
            is_prefix => 1
        };
    }

    if ($token->{Class} eq 'identifier') {
        my $identifier = {
            type => 'Identifier',
            value => $token->{Text},
            Pos => $self->get_next_token_pos()
        };
        $self->consume_token();

        my $next_token = $self->current_token();
        if ($next_token->{Name} eq 'dot') {
            return $self->parse_package_or_field_access($identifier);
        }

        if ($next_token->{Name} eq 'colon') {
            $self->consume_token();

            my $field_value = $self->parse_expression();
            return {
                type => 'StructField',
                name => $identifier->{value},
                value => $field_value
            };
        }

        if ($next_token->{Name} eq 'l_paren') {
            return $self->parse_function_call($identifier);
        }

        my $postfix_token = $self->current_token();
        if ($postfix_token->{Name} eq 'increment' || $postfix_token->{Name} eq 'decrement') {
            my $operator = $postfix_token->{Text};
            $self->consume_token();

            return {
                type => 'UnaryOperation',
                operator => {
                    type => 'Operator',
                    value => $operator,
                    Pos => $self->get_next_token_pos()
                },
                operand => $identifier,
                is_prefix => 0
            };
        } else {
            return $identifier;
        }
    } elsif ($token->{Class} eq 'constant' && $token->{Name} eq 'number') {
         my $text = $token->{Text};

        my $type;
        if ($text =~ /^[+-]?\d+$/) {
            $type = 'IntLiteral';
        } elsif ($text =~ /^[+-]?(?:\d+\.\d*|\.\d+)(?:[eE][+-]?\d+)?$/ || $text =~ /^[+-]?\d+[eE][+-]?\d+$/) {
            $type = 'FloatLiteral';
        } else {
            die "Invalid numeric literal: $text";
        }

        $self->consume_token();
        return {
            type  => $type,
            value => $text,
            Pos   => $self->get_next_token_pos()
        };
    } elsif ($token->{Class} eq 'constant' && $token->{Name} eq 'string') {
        $self->consume_token();
        return {
            type => 'StringLiteral',
            value => $token->{Text},
            Pos => $self->get_next_token_pos()
        };
    } elsif ($token->{Class} eq 'constant' && $token->{Name} eq 'boolean') {
        $self->consume_token();
        return {
            type => 'BoolLiteral',
            value => $token->{Text},
            Pos => $self->get_next_token_pos()
        };
    } elsif ($token->{Name} eq 'l_paren') {
        $self->consume_token();
        my $expr = $self->parse_expression();
        my $r_paren = $self->current_token();
        if ($r_paren->{Name} eq 'r_paren') {
            $self->consume_token();
            return $expr;
        } else {
            die "Ожидалась ')' после выражения";
        }
    } elsif ($token->{Name} eq 'semicolon') {
        $self->consume_token();
        return undef;
    } else {
        die "Ожидалось простое выражение (идентификатор, число или выражение в скобках)";
    }
}

# Парсинг вызова функции пакета или доступа к полю
sub parse_package_or_field_access {
    my ($self, $identifier) = @_;
    print "parse_package_or_field_access\n";

    $self->consume_token();

    my $field_or_func_token = $self->current_token();
    if ($field_or_func_token->{Class} eq 'identifier') {
        $self->consume_token();

        my $next_token = $self->current_token();

        if ($next_token->{Name} eq 'l_paren') {
            return $self->parse_function_call({
                type => 'PackageCall',
                package => $identifier,
                function => {
                    type => 'Identifier',
                    value => $field_or_func_token->{Text},
                    Pos => $self->get_next_token_pos()
                }
            });
        } else {
            return {
                type => 'FieldAccess',
                object => $identifier,
                field => {
                    type => 'Identifier',
                    value => $field_or_func_token->{Text},
                    Pos => $self->get_next_token_pos()
                }
            };
        }
    } else {
        die "Ожидалось имя поля или функции после точки";
    }
}

# Парсинг логических выражений (&&, ||)
sub parse_logical_expression {
    my ($self) = @_;
    print "parse_logical_expression\n";
    my $left = $self->parse_relational_expression();

    while (1) {
        my $operator = $self->current_token();
        if ($operator->{Class} eq 'operator' && 
            ($operator->{Name} eq 'logical_and' || $operator->{Name} eq 'logical_or')) {
            $self->consume_token();
            my $operator_pos = $self->{token_counter};  # Позиция оператора
            my $right = $self->parse_relational_expression();
            $left = {
                type => 'LogicalExpression',
                left => $left,
                operator => {
                    type => 'Operator',
                    value => $operator->{Text},
                    Pos => $operator_pos
                },
                right => $right,
            };
        } else {
            last;
        }
    }
    return $left;
}

# Парсинг реляционных выражений (>, <, >=, <=, ==, !=)
sub parse_relational_expression {
    my ($self) = @_;
    print "parse_relational_expression\n";
    my $left = $self->parse_additive_expression();

    while (1) {
        my $operator = $self->current_token();
        if ($operator->{Class} eq 'operator' && 
            ($operator->{Name} eq 'greater' || $operator->{Name} eq 'less' || 
             $operator->{Name} eq 'greater_equal' || $operator->{Name} eq 'less_equal' || 
             $operator->{Name} eq 'equal' || $operator->{Name} eq 'not_equal')) {
            $self->consume_token();
            my $operator_pos = $self->{token_counter};  # Позиция оператора
            my $right = $self->parse_additive_expression();
            $left = {
                type => 'RelationalExpression',
                left => $left,
                operator => {
                    type => 'Operator',
                    value => $operator->{Text},
                    Pos => $operator_pos
                },
                right => $right,
            };
        } else {
            last;
        }
    }
    return $left;
}

# Парсинг условия if
sub parse_if_statement {
    my ($self) = @_;
    print "parse_if_statement\n";
    my @nodes;

    my $if_token = $self->current_token();
    if ($if_token->{Name} eq 'if') {
        push @nodes, { Name => $if_token->{Name}, Text => $if_token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();

        # Условие if
        my $condition = $self->parse_logical_expression();

        # Открывающая фигурная скобка для тела условия
        my $l_brace = $self->current_token();
        if ($l_brace->{Name} eq 'l_brace') {
            push @nodes, { Name => $l_brace->{Name}, Text => $l_brace->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась '{' после условия 'if'";
        }

        # Тело условия if
        my @if_body;
        while ($self->current_token()->{Name} ne 'r_brace') {
            my $stmt = $self->parse_statement();
            push @if_body, $stmt if $stmt;
        }

        # Закрывающая фигурная скобка для тела условия
        my $r_brace = $self->current_token();
        if ($r_brace->{Name} eq 'r_brace') {
            push @nodes, { Name => $r_brace->{Name}, Text => $r_brace->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась '}' после тела условия";
        }

        # Обработка else if и else
        my @else_if_nodes;
        my @else_body;
        while ($self->current_token()->{Name} eq 'else') {
            my $else_token = $self->current_token();
            push @nodes, { Name => $else_token->{Name}, Text => $else_token->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();

            if ($self->current_token()->{Name} eq 'if') {
                # Обработка else if
                my $else_if_token = $self->current_token();
                push @nodes, { Name => $else_if_token->{Name}, Text => $else_if_token->{Text}, Pos => $self->get_next_token_pos() };
                $self->consume_token();

                # Условие else if
                my $else_if_condition = $self->parse_logical_expression();

                # Открывающая фигурная скобка для тела else if
                my $l_brace_else_if = $self->current_token();
                if ($l_brace_else_if->{Name} eq 'l_brace') {
                    push @nodes, { Name => $l_brace_else_if->{Name}, Text => $l_brace_else_if->{Text}, Pos => $self->get_next_token_pos() };
                    $self->consume_token();
                } else {
                    die "Ожидалась '{' после условия 'else if'";
                }

                # Тело else if
                my @else_if_body;
                while ($self->current_token()->{Name} ne 'r_brace') {
                    my $stmt = $self->parse_statement();
                    push @else_if_body, $stmt if $stmt;
                }

                # Закрывающая фигурная скобка для тела else if
                my $r_brace_else_if = $self->current_token();
                if ($r_brace_else_if->{Name} eq 'r_brace') {
                    push @nodes, { Name => $r_brace_else_if->{Name}, Text => $r_brace_else_if->{Text}, Pos => $self->get_next_token_pos() };
                    $self->consume_token();
                } else {
                    die "Ожидалась '}' после тела else if";
                }

                push @else_if_nodes, {
                    type => 'ElseIfStatement',
                    condition => $else_if_condition,
                    body => \@else_if_body,
                };
            } else {
                # Обработка else
                # Открывающая фигурная скобка для тела else
                my $l_brace_else = $self->current_token();
                if ($l_brace_else->{Name} eq 'l_brace') {
                    push @nodes, { Name => $l_brace_else->{Name}, Text => $l_brace_else->{Text}, Pos => $self->get_next_token_pos() };
                    $self->consume_token();
                } else {
                    die "Ожидалась '{' после 'else'";
                }

                # Тело else
                while ($self->current_token()->{Name} ne 'r_brace') {
                    my $stmt = $self->parse_statement();
                    push @else_body, $stmt if $stmt;
                }

                # Закрывающая фигурная скобка для тела else
                my $r_brace_else = $self->current_token();
                if ($r_brace_else->{Name} eq 'r_brace') {
                    push @nodes, { Name => $r_brace_else->{Name}, Text => $r_brace_else->{Text}, Pos => $self->get_next_token_pos() };
                    $self->consume_token();
                } else {
                    die "Ожидалась '}' после тела else";
                }
            }
        }

        return {
            type => 'IfStatement',
            condition => $condition,
            body => \@if_body,
            else_if => \@else_if_nodes,
            else_body => \@else_body,
            nodes => \@nodes
        };
    }
    return undef;
}

# Парсинг вызова функции
sub parse_function_call {
    my ($self, $function_info) = @_;
    print "parse_function_call\n";
    my @nodes;

    # Если информация о функции передана (например, из parse_package_or_field_access)
    my $package_name = undef;
    my $function_name;

    if ($function_info) {
        if ($function_info->{type} eq 'PackageCall') {
            $package_name = $function_info->{package}->{value};
            $function_name = $function_info->{function}->{value};
        } else {
            $function_name = $function_info->{value};
        }
    } else {
        $function_name = $self->current_token();
        if ($function_name->{Class} eq 'identifier') {
            $self->consume_token();
        } else {
            die "Ожидалось имя функции";
        }
    }

    # Открывающая скобка для аргументов
    my $l_paren = $self->current_token();
    if ($l_paren->{Name} eq 'l_paren') {
        push @nodes, { Name => $l_paren->{Name}, Text => $l_paren->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась '(' после имени функции";
    }

    # Парсинг аргументов функции
    my @args;
    while ($self->current_token()->{Name} ne 'r_paren') {
        my $is_reference = 0;
        my $bitwise_and = $self->current_token();
        if ($bitwise_and->{Name} eq 'bitwise_and') {
            $is_reference = 1;
            push @nodes, { Name => $bitwise_and->{Name}, Text => $bitwise_and->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        }

        my $arg = $self->parse_expression();

        if ($is_reference) {
            $arg->{is_by_reference} = 1;
        }

        push @args, $arg;

        my $comma = $self->current_token();
        if ($comma->{Name} eq 'comma') {
            push @nodes, { Name => $comma->{Name}, Text => $comma->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } elsif ($self->current_token()->{Name} ne 'r_paren') {
            die "Ожидалась ',' или ')' после аргумента";
        }
    }

    # Закрывающая скобка для аргументов
    my $r_paren = $self->current_token();
    if ($r_paren->{Name} eq 'r_paren') {
        push @nodes, { Name => $r_paren->{Name}, Text => $r_paren->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась ')' после аргументов функции";
    }

    # Возвращаем структуру вызова функции
    return {
        type => 'FunctionCall',
        package => $package_name,
        name => $function_name,
        args => \@args,
        nodes => \@nodes
    };
}

# Парсинг конструкции switch-case
sub parse_switch_statement {
    my ($self) = @_;
    print "parse_switch_statement\n";
    my @nodes;

    # Токен 'switch'
    my $switch_token = $self->current_token();
    if ($switch_token->{Name} eq 'switch') {
        push @nodes, { Name => $switch_token->{Name}, Text => $switch_token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();

        # Выражение после switch
        my $condition = $self->parse_expression();

        # Открывающая фигурная скобка для тела switch
        my $l_brace = $self->current_token();
        if ($l_brace->{Name} eq 'l_brace') {
            push @nodes, { Name => $l_brace->{Name}, Text => $l_brace->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась '{' после выражения в switch";
        }

        # Парсинг case и default
        my @cases;
        while ($self->current_token()->{Name} ne 'r_brace') {
            my $case_token = $self->current_token();
            if ($case_token->{Name} eq 'case') {
                # Обработка case
                push @nodes, { Name => $case_token->{Name}, Text => $case_token->{Text}, Pos => $self->get_next_token_pos() };
                $self->consume_token();

                # Значение case
                my $case_value = $self->parse_expression();

                # Двоеточие после значения case
                my $colon = $self->current_token();
                if ($colon->{Name} eq 'colon') {
                    push @nodes, { Name => $colon->{Name}, Text => $colon->{Text}, Pos => $self->get_next_token_pos() };
                    $self->consume_token();
                } else {
                    die "Ожидалось ':' после значения case";
                }

                # Тело case
                my @case_body;
                while ($self->current_token()->{Name} ne 'case' && $self->current_token()->{Name} ne 'default' && $self->current_token()->{Name} ne 'r_brace') {
                    my $stmt = $self->parse_statement();
                    push @case_body, $stmt if $stmt;
                }

                push @cases, {
                    type => 'CaseStatement',
                    value => $case_value,
                    body => \@case_body,
                };
            } elsif ($case_token->{Name} eq 'default') {
                # Обработка default
                push @nodes, { Name => $case_token->{Name}, Text => $case_token->{Text}, Pos => $self->get_next_token_pos() };
                $self->consume_token();

                # Двоеточие после default
                my $colon = $self->current_token();
                if ($colon->{Name} eq 'colon') {
                    push @nodes, { Name => $colon->{Name}, Text => $colon->{Text}, Pos => $self->get_next_token_pos() };
                    $self->consume_token();
                } else {
                    die "Ожидалось ':' после default";
                }

                # Тело default
                my @default_body;
                while ($self->current_token()->{Name} ne 'r_brace') {
                    my $stmt = $self->parse_statement();
                    push @default_body, $stmt if $stmt;
                }

                push @cases, {
                    type => 'DefaultStatement',
                    body => \@default_body,
                };
            } else {
                die "Ожидался 'case' или 'default' внутри switch";
            }
        }

        # Закрывающая фигурная скобка для тела switch
        my $r_brace = $self->current_token();
        if ($r_brace->{Name} eq 'r_brace') {
            push @nodes, { Name => $r_brace->{Name}, Text => $r_brace->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась '}' после тела switch";
        }

        return {
            type => 'SwitchStatement',
            condition => $condition,
            cases => \@cases,
            nodes => \@nodes,
        };
    }
    return undef;
}

# Парсинг цикла for
sub parse_for_loop {
    my ($self) = @_;
    print "parse_for_loop\n";
    my @nodes;

    # Токен 'for'
    my $for_token = $self->current_token();
    if ($for_token->{Name} eq 'for') {
        push @nodes, { Name => $for_token->{Name}, Text => $for_token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалось ключевое слово 'for'";
    }

    # Определяем тип цикла
    my $loop_type = 'standard';  # По умолчанию стандартный цикл
    my $init;                    # Инициализация
    my $condition;               # Условие
    my $iteration;               # Итерация
    my $range;                   # Для цикла с range
    my $body;                    # Тело цикла
    my $index;                   # Первая переменная в цикле с range
    my $value;                   # Вторая переменная в цикле с range

    # Проверяем, есть ли инициализация (например, i := 0)
    my $next_token = $self->current_token();
    my $next_next_token = $self->next_token();

    if ($next_token->{Name} eq 'l_brace') {
        $loop_type = 'infinite';
    }

    elsif ($next_token->{Class} eq 'identifier' && $next_next_token->{Name} eq 'comma') {

        $loop_type = 'range';

        $index = $self->current_token();
        push @nodes, { Name => $index->{Name}, Text => $index->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();

        my $comma = $self->current_token();
        if ($comma->{Name} eq 'comma') {
            push @nodes, { Name => $comma->{Name}, Text => $comma->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась ',' после первого идентификатора";
        }

        $value = $self->current_token();
        if ($value->{Class} eq 'identifier') {
            push @nodes, { Name => $value->{Name}, Text => $value->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидался второй идентификатор";
        }

        my $declaration = $self->current_token();
        if ($declaration->{Name} eq 'declaration') {
            push @nodes, { Name => $declaration->{Name}, Text => $declaration->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалось ':=' после идентификаторов";
        }

        my $range_token = $self->current_token();
        if ($range_token->{Name} eq 'range') {
            push @nodes, { Name => $range_token->{Name}, Text => $range_token->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалось ключевое слово 'range'";
        }

        $range = $self->parse_expression();
    }
    elsif ($next_token->{Class} eq 'identifier' && $next_next_token->{Name} eq 'declaration') {
        $loop_type = 'standard';

        $init = $self->parse_variable_declaration();
        
        if ($self->current_token()->{Name} eq 'semicolon' || $self->has_semicolon($init)) {
            if ($self->current_token()->{Name} eq 'semicolon') {
                $self->consume_token();
            }
        } else {
            die "Ожидалось ';' после инициализации";
        }

        $condition = $self->parse_logical_expression();

        if ($self->current_token()->{Name} eq 'semicolon') {
            $self->consume_token();
        } else {
            die "Ожидалось ';' после условия";
        }

        $iteration = $self->parse_statement();
    } else {
        $loop_type = 'condition_only';
        $condition = $self->parse_logical_expression();
    }

    # Открывающая фигурная скобка для тела цикла
    my $l_brace = $self->current_token();
    if ($l_brace->{Name} eq 'l_brace') {
        push @nodes, { Name => $l_brace->{Name}, Text => $l_brace->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась '{' после объявления цикла";
    }

    # Парсим тело цикла
    my @body;
    while ($self->current_token()->{Name} ne 'r_brace') {
        my $stmt = $self->parse_statement();
        push @body, $stmt if $stmt;
    }

    # Закрывающая фигурная скобка для тела цикла
    my $r_brace = $self->current_token();
    if ($r_brace->{Name} eq 'r_brace') {
        push @nodes, { Name => $r_brace->{Name}, Text => $r_brace->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();
    } else {
        die "Ожидалась '}' после тела цикла";
    }

    # Возвращаем структуру цикла
    return {
        type => 'ForLoop',
        loop_type => $loop_type,
        init => $init,
        condition => $condition,
        iteration => $iteration,
        range => $range,
        index => $index ? $index->{Text} : undef,
        value => $value ? $value->{Text} : undef,
        body => \@body,
        nodes => \@nodes
    };
}

sub has_semicolon {
    my ($self, $data) = @_;

    return 0 unless exists $data->{nodes};

    foreach my $node (@{$data->{nodes}}) {
        if (exists $node->{Name} && $node->{Name} eq 'semicolon') {
            return 1;
        }
    }

    return 0;
}

# Главная функция разбора
sub parse {
    my ($self) = @_;
    print "parse\n";
    my @children;
    
    while (my $token = $self->current_token()) {
        if ($token->{Name} eq 'package') {
            push @children, $self->parse_package();
        } elsif ($token->{Name} eq 'import') {
            push @children, $self->parse_import();
        } elsif ($token->{Name} eq 'type') {
            push @children, $self->parse_type_declaration();
        } elsif ($token->{Name} eq 'const') {
            push @children, $self->parse_const_declaration();
        } elsif ($token->{Name} eq 'func') {
            push @children, $self->parse_function();
        } elsif ($token->{Class} eq 'identifier') {
            push @children, $self->parse_variable_declaration();
        } elsif ($token->{Class} eq 'EOF') {
            last;
        } else {
            die "Неожиданный токен: $token->{Text}";
        }
    }

    # Возвращаем корневую ноду Program с дочерними нодами
    return { type => 'Program', children => \@children };
}

# Возвращает таблицу символов
sub get_symbol_table {
    my ($self) = @_;
    return $self->{symbol_table};
}

# Метод для получения списка импортов
sub get_imports {
    my ($self) = @_;
    return $self->{imports};
}


1;
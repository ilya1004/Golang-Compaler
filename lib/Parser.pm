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
            types => {}, 
            variables => {}, 
            constants => {} 
            },
        imports => []            # Список импортов
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
            Pos => $self->get_next_token_pos()  # Используем get_next_token_pos
        };
        $self->consume_token();

        my $ident = $self->current_token();
        if ($ident->{Class} eq 'identifier') {
            push @nodes, {
                Name => $ident->{Name},
                Text => $ident->{Text},
                Pos => $self->get_next_token_pos()  # Используем get_next_token_pos
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
                Pos => $self->get_next_token_pos()  # Используем get_next_token_pos
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
        push @nodes, { Name => $token->{Name}, Text => $token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();

        # Проверяем, есть ли скобки для множественного импорта
        my $has_paren = 0;
        my $next_token = $self->current_token();
        if ($next_token->{Name} eq 'l_paren') {
            $has_paren = 1;
            push @nodes, { Name => $next_token->{Name}, Text => $next_token->{Text}, Pos => $self->get_next_token_pos() };
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
                    package   => { Name => $import_token->{Name}, Text => $import_token->{Text}, Pos => $self->get_next_token_pos() },
                    semicolon => { Name => $semicolon->{Name}, Text => $semicolon->{Text}, Pos => $self->get_next_token_pos() }
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
                push @nodes, { Name => $r_paren->{Name}, Text => $r_paren->{Text}, Pos => $self->get_next_token_pos() };
                $self->consume_token();
            } else {
                die "Ожидалась ')' после списка импортов";
            }
        }

        # Точка с запятой после импорта (если есть)
        my $semicolon = $self->current_token();
        if ($semicolon->{Name} eq 'semicolon') {
            push @nodes, { Name => $semicolon->{Name}, Text => $semicolon->{Text}, Pos => $self->get_next_token_pos() };
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
        push @nodes, { Name => $type_token->{Name}, Text => $type_token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();

        # Имя типа
        my $type_name = $self->current_token();
        if ($type_name->{Class} eq 'identifier') {
            push @nodes, { Name => $type_name->{Name}, Text => $type_name->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалось имя типа после 'type'";
        }

        # Ключевое слово struct
        my $struct_token = $self->current_token();
        if ($struct_token->{Name} eq 'struct') {
            push @nodes, { Name => $struct_token->{Name}, Text => $struct_token->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалось ключевое слово 'struct'";
        }

        # Открывающая фигурная скобка
        my $l_brace = $self->current_token();
        if ($l_brace->{Name} eq 'l_brace') {
            push @nodes, { Name => $l_brace->{Name}, Text => $l_brace->{Text}, Pos => $self->get_next_token_pos() };
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
                            field_name => { Name => $field_name->{Name}, Text => $field_name->{Text}, Pos => $self->get_next_token_pos() },
                            field_type => { Name => $field_type->{Name}, Text => $field_type->{Text}, Pos => $self->get_next_token_pos() },
                            semicolon  => { Name => $semicolon->{Name}, Text => $semicolon->{Text}, Pos => $self->get_next_token_pos() }
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

    my $var_name = $self->current_token();
    if ($var_name->{Class} eq 'identifier') {
        push @nodes, { Name => $var_name->{Name}, Text => $var_name->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();

        # Проверяем, является ли это коротким объявлением (:=)
        my $declaration_token = $self->current_token();
        if ($declaration_token->{Name} eq 'declaration') {
            push @nodes, { Name => $declaration_token->{Name}, Text => $declaration_token->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();

            # Парсим выражение после :=
            my $expression = $self->parse_expression();

            # Определяем тип переменной
            my $var_type = 'auto';
            if ($expression->{type} eq 'StructLiteral') {
                # Если это литерал структуры, используем имя структуры как тип
                $var_type = $expression->{struct_type};
            }

            # Добавляем переменную в таблицу символов
            $self->{symbol_table}{variables}{$var_name->{Text}} = $var_type;

            push @nodes, { type => 'Expression', value => $expression };
        } else {
            # Это явное объявление переменной с типом
            my $var_type = $self->current_token();
            my $is_valid_type = 0;

            # Проверяем, является ли тип допустимым (встроенным или кастомным)
            foreach my $keyword (@keywords) {
                if ($var_type->{Name} eq $keyword->{Name}) {
                    $is_valid_type = 1;
                    last;
                }
            }

            # Если тип не встроенный, проверяем, является ли он кастомным типом
            if (!$is_valid_type && $var_type->{Class} eq 'identifier') {
                $is_valid_type = 1; # Кастомный тип считается допустимым
            }

            if ($is_valid_type) {
                push @nodes, { Name => $var_type->{Name}, Text => $var_type->{Text}, Pos => $self->get_next_token_pos() };
                $self->consume_token();

                # Добавляем переменную в таблицу символов
                $self->{symbol_table}{variables}{$var_name->{Text}} = $var_type->{Text};
            } else {
                # Если это не тип, то это может быть оператор присваивания (например, a += b)
                # В таком случае передаем управление parse_expression
                return $self->parse_expression();
            }
        }

        # Точка с запятой после объявления (если она есть)
        my $semicolon = $self->current_token();
        if ($semicolon->{Name} eq 'semicolon') {
            push @nodes, { Name => $semicolon->{Name}, Text => $semicolon->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } elsif ($semicolon->{Name} ne 'EOF' && $semicolon->{Line} == $var_name->{Line}) {
            # Если точка с запятой отсутствует, но выражение не на новой строке, выбрасываем ошибку
            die "Ожидалась ';' после объявления переменной";
        }
    }
    return { type => 'VariableDeclaration', nodes => \@nodes };
}

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

    # Оператор присваивания
    my $assign_token = $self->current_token();
    print "$assign_token->{Name}\n";
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
    $self->{symbol_table}{constants}{$const_name->{Text}} = {
        value => $const_value->{Text},
        scope => $self->{current_scope} || '-Global-',  # Область видимости
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
            my $param_type = $self->current_token();
            if ($param_type->{Class} eq 'keyword' || $param_type->{Class} eq 'identifier') {
                $self->consume_token();
            } else {
                die "Ожидался тип параметра";
            }

            # Добавляем параметры в таблицу символов с областью видимости, привязанной к функции
            foreach my $param_name (@param_names) {
                $self->{symbol_table}{variables}{$param_name->{Text}} = {
                    type => $param_type->{Text},
                    scope => $func_name->{Text},  # Область видимости — имя функции
                    pos => $self->{token_counter}  # Текущее значение счетчика токенов
                };

                push @params, {
                    param_name => { Name => $param_name->{Name}, Text => $param_name->{Text}, Pos => $self->get_next_token_pos() },
                    param_type => { Name => $param_type->{Name}, Text => $param_type->{Text}, Pos => $self->get_next_token_pos() }
                };
            }

            # Запятая между группами параметров (если есть)
            my $comma = $self->current_token();
            if ($comma->{Name} eq 'comma') {
                $self->consume_token();
            } elsif ($self->current_token()->{Name} ne 'r_paren') {
                die "Ожидалась ',' или ')' после параметра";
            }
        }

        # Закрывающая скобка для параметров
        my $r_paren = $self->current_token();
        if ($r_paren->{Name} eq 'r_paren') {
            push @nodes, { Name => $r_paren->{Name}, Text => $r_paren->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась ')' после параметров функции";
        }

        # Парсинг возвращаемых значений
        my @return_types;
        my $return_token = $self->current_token();
        if ($return_token->{Name} eq 'l_paren') {
            # Если возвращаемых значений несколько (в скобках)
            push @nodes, { Name => $return_token->{Name}, Text => $return_token->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();

            while ($self->current_token()->{Name} ne 'r_paren') {
                my $return_type = $self->current_token();
                if ($return_type->{Class} eq 'keyword' || $return_type->{Class} eq 'identifier') {
                    push @return_types, { Name => $return_type->{Name}, Text => $return_type->{Text}, Pos => $self->get_next_token_pos() };
                    $self->consume_token();
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

            # Закрывающая скобка для возвращаемых значений
            my $r_paren_return = $self->current_token();
            if ($r_paren_return->{Name} eq 'r_paren') {
                push @nodes, { Name => $r_paren_return->{Name}, Text => $r_paren_return->{Text}, Pos => $self->get_next_token_pos() };
                $self->consume_token();
            } else {
                die "Ожидалась ')' после возвращаемых значений";
            }
        } elsif ($return_token->{Class} eq 'keyword' || $return_token->{Class} eq 'identifier') {
            # Если возвращаемое значение одно
            push @return_types, { Name => $return_token->{Name}, Text => $return_token->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        }

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

# Парсинг выражения (вызов функции, оператор, литерал структуры и т.д.)
sub parse_expression {
    my ($self) = @_;
    return $self->parse_assignment_expression();
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
    unless ($struct_type) {
        $struct_type = $self->{current_struct_type} // 'auto';
    }

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
    my @nodes;

    my $return_token = $self->current_token();
    if ($return_token->{Name} eq 'return') {
        push @nodes, { Name => $return_token->{Name}, Text => $return_token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();

        # Парсим выражение после return
        my $expression = $self->parse_expression();

        # Точка с запятой после return (если она есть)
        my $semicolon = $self->current_token();
        if ($semicolon->{Name} eq 'semicolon') {
            push @nodes, { Name => $semicolon->{Name}, Text => $semicolon->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } elsif ($semicolon->{Name} ne 'EOF' && $semicolon->{Line} == $return_token->{Line}) {
            # Если точка с запятой отсутствует, но выражение не на новой строке, выбрасываем ошибку
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
    print "$token->{Text}\n";
    print "$token->{Class}\n";

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
    } elsif (($token->{Class} eq 'identifier' && $next_token->{Name} eq 'l_paren') ||
             ($token->{Class} eq 'identifier' && $self->contains_string($token->{Text}))) {
        # Вызов функции
        return $self->parse_function_call();
    } else {
        # Выражение (оператор, присваивание и т.д.)
        return $self->parse_expression();
    }
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

    if ($token->{Class} eq 'identifier') {
        # Проверяем, является ли следующий токен открывающей скобкой (вызов функции)
        my $next_token = $self->next_token();
        if ($next_token->{Name} eq 'l_paren') {
            return $self->parse_function_call();  # Парсим вызов функции
        } else {
            # Это просто идентификатор
            $self->consume_token();
            return {
                type => 'Identifier', 
                value => $token->{Text}, 
                Pos => $self->get_next_token_pos()  # Добавляем позицию
            };
        }
    } elsif ($token->{Class} eq 'constant' && $token->{Name} eq 'number') {
        $self->consume_token();
        return { 
            type => 'NumberLiteral', 
            value => $token->{Text}, 
            Pos => $self->get_next_token_pos()  # Добавляем позицию
        };
    } elsif ($token->{Class} eq 'constant' && $token->{Name} eq 'string') {
        $self->consume_token();
        return { 
            type => 'StringLiteral', 
            value => $token->{Text}, 
            Pos => $self->get_next_token_pos()  # Добавляем позицию
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
        # Точка с запятой не является частью выражения, просто пропускаем её
        $self->consume_token();
        return undef;  # Возвращаем undef, чтобы не добавлять её в AST
    } else {
        die "Ожидалось простое выражение (идентификатор, число или выражение в скобках)";
    }
}

# Парсинг цикла for
sub parse_for_loop {
    my ($self) = @_;
    my @nodes;

    my $for_token = $self->current_token();
    if ($for_token->{Name} eq 'for') {
        push @nodes, { Name => $for_token->{Name}, Text => $for_token->{Text}, Pos => $self->get_next_token_pos() };
        $self->consume_token();

        # Открывающая фигурная скобка для тела цикла
        my $l_brace = $self->current_token();
        if ($l_brace->{Name} eq 'l_brace') {
            push @nodes, { Name => $l_brace->{Name}, Text => $l_brace->{Text}, Pos => $self->get_next_token_pos() };
            $self->consume_token();
        } else {
            die "Ожидалась '{' после 'for'";
        }

        # Тело цикла
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

        return { type => 'ForLoop', body => \@body, nodes => \@nodes };
    }
    return undef;
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
    my ($self) = @_;
    print "parse_function_call\n";
    my @nodes;

    # Парсинг имени функции (может быть с пакетом, например, fmt.Print)
    my $package_name = undef;
    my $function_name = $self->current_token();

    if ($function_name->{Class} eq 'identifier') {
        $self->consume_token();

        # Проверяем, есть ли точка (например, fmt.Print)
        my $dot = $self->current_token();
        if ($dot->{Name} eq 'dot') {
            $package_name = $function_name->{Text};  # Сохраняем имя пакета
            $self->consume_token();

            # Парсинг имени функции после точки
            $function_name = $self->current_token();
            if ($function_name->{Class} eq 'identifier') {
                $self->consume_token();
            } else {
                die "Ожидалось имя функции после точки";
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
            my $arg = $self->parse_expression();  # Парсим выражение как аргумент
            push @args, $arg;

            # Запятая между аргументами (если есть)
            my $comma = $self->current_token();
            if ($comma->{Name} eq 'comma') {
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
            package => $package_name,  # Имя пакета (если есть)
            name => $function_name->{Text},  # Имя функции
            args => \@args,  # Список аргументов
            nodes => \@nodes
        };
    } else {
        die "Ожидалось имя функции";
    }
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
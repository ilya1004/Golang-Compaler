use strict;
use warnings;
use Data::Dumper;
use JSON;

use lib '../lib';
use Lexer;
use Parser;
use SemanticAnalyzer;
use Interpreter;

our $index = 0;
our %ids;

my $filename = '../test-code/test-1/main.go';

open(my $fh, '<', $filename) or die "Не удалось открыть файл '$filename': $!";
my $code = do { local $/; <$fh> };
close($fh);

my $output_dir = 'results';
unless(-d $output_dir) {
    mkdir $output_dir or die "Не удалось создать директорию '$output_dir': $!";
}

my $lexer = Lexer->new($code);
my $tokens = $lexer->lex_analyze();

my $parser = Parser->new($tokens);
my $cst = $parser->parse();
my $symbol_table = $parser->get_symbol_table();
my $imports = $parser->get_imports();

# Сериализация токенов в JSON
my $tokens_json = to_json($tokens, { 
    pretty => 1,
    canonical => 1,
});

# Сериализация CST в JSON
my $cst_json = to_json($cst, { 
    pretty => 1,
    canonical => 1,
});

# Сериализация таблицы символов в JSON
my $symbol_table_json = to_json($symbol_table, {
    pretty => 1,
    canonical => 1,
});

# Сериализация импортов в JSON
my $imports_json = to_json($imports, {
    pretty => 1,
    canonical => 1,
});

# Запись токенов в файл
my $tokens_filename = "$output_dir/res_tokens.json";
open(my $tokens_fh, '>', $tokens_filename) or die "Не удалось открыть файл '$tokens_filename' для записи: $!";
print $tokens_fh $tokens_json;
close($tokens_fh);

# Запись CST в файл
my $cst_filename = "$output_dir/res_cst.json";
open(my $cst_fh, '>', $cst_filename) or die "Не удалось открыть файл '$cst_filename' для записи: $!";
print $cst_fh $cst_json;
close($cst_fh);

# Запись таблицы символов в файл
my $symbol_table_filename = "$output_dir/res_symbol_table.json";
open(my $symbol_table_fh, '>', $symbol_table_filename) or die "Не удалось открыть файл '$symbol_table_filename' для записи: $!";
print $symbol_table_fh $symbol_table_json;
close($symbol_table_fh);

# Запись импортов в файл
my $imports_filename = "$output_dir/res_imports.json";
open(my $imports_fh, '>', $imports_filename) or die "Не удалось открыть файл '$imports_filename' для записи: $!";
print $imports_fh $imports_json;
close($imports_fh);

print "Токены успешно записаны в файл '$tokens_filename'.\n";
print "CST успешно записан в файл '$cst_filename'.\n";
print "Таблица символов успешно записана в файл '$symbol_table_filename'.\n";
print "Список импортов успешно записан в файл '$imports_filename'.\n";

# Вызов семантического анализатора
my $analyzer = SemanticAnalyzer->new($cst, $symbol_table, $imports);
my $errors = $analyzer->analyze();

# Вывод результатов семантического анализа
print "\n-----------------------------------------\n";
print "Результаты семантического анализа:\n";
if (@$errors) {
    print "Найдены семантические ошибки:\n";
    foreach my $error (@$errors) {
        my $token = $tokens->[$error->{pos}] || {};
        my $line = $token->{Line} || 'неизвестно';
        my $column = $token->{Column} || 'неизвестно';
        print "Ошибка: $error->{message} (позиция: $error->{pos}, строка: $line, столбец: $column)\n";
    }

    # Сохранение результатов семантического анализа в файл
    my $semantic_errors_filename = "$output_dir/res_semantic_errors.json";
    open(my $semantic_fh, '>', $semantic_errors_filename) or die "Не удалось открыть файл '$semantic_errors_filename' для записи: $!";
    print $semantic_fh to_json($errors, { pretty => 1, canonical => 1 });
    close($semantic_fh);
    print "Результаты семантического анализа записаны в файл '$semantic_errors_filename'.\n";

} else {
    print "Семантический анализ прошел успешно, ошибок не найдено.\n";

    # Сохранение результатов семантического анализа в файл
    my $semantic_errors_filename = "$output_dir/res_semantic_errors.json";
    open(my $semantic_fh, '>', $semantic_errors_filename) or die "Не удалось открыть файл '$semantic_errors_filename' для записи: $!";
    print $semantic_fh to_json($errors, { pretty => 1, canonical => 1 });
    close($semantic_fh);
    print "Результаты семантического анализа записаны в файл '$semantic_errors_filename'.\n";

    print "\n\nВыполнение программы:";
    print "\n-----------------------------------------\n";
    # Вызов интерпретатора

    # Проверка аргументов командной строки
    my $debug_mode = 0;  # По умолчанию -release
    my @input_values = ();

    if (@ARGV && $ARGV[0] =~ /^-(debug|release)$/) {
        my $mode = $1;
        $debug_mode = 1 if $mode eq 'debug';
        @input_values = @ARGV[1..$#ARGV];
    } elsif (@ARGV) {
        die "Invalid flag: $ARGV[0]. Use -debug or -release.\n";
    }

    # Создание интерпретатора
    my $interpreter = Interpreter->new($cst, $symbol_table, $imports, $debug_mode);

    # Установка входного буфера
    $interpreter->{input_buffer} = [@input_values] if @input_values;


    eval {
        $interpreter->interpret();
    };
    if ($@) {
        print "Ошибка выполнения: $@\n";
    }
    print "\n-----------------------------------------\n";
}

open(my $main_fh,         '>', "$output_dir/lex_result.txt")       or die "Не удалось создать файл result.txt: $!";
open(my $keywords_fh,     '>', "$output_dir/lex_keywords.txt")     or die "Не удалось создать файл keywords.txt: $!";
open(my $operators_fh,    '>', "$output_dir/lex_operators.txt")    or die "Не удалось создать файл operators.txt: $!";
open(my $identifiers_fh,  '>', "$output_dir/lex_identifiers.txt")  or die "Не удалось создать файл identifiers.txt: $!";
open(my $constants_fh,    '>', "$output_dir/lex_constants.txt")    or die "Не удалось создать файл constants.txt: $!";
open(my $punctuations_fh, '>', "$output_dir/lex_punctuations.txt") or die "Не удалось создать файл punctuations.txt: $!";

my $header    = sprintf("%-35s %-24s %-15s %-20s %-10s\n", "Лексема", "Токен", "Строка", "Столбец", "ID");
my $separator = "=================================================================================\n";

print $main_fh $header, $separator;

my (%unique_keywords, %unique_operators, %unique_identifiers, %unique_constants, %unique_punctuations);
my ($id_kw, $id_op, $id_var, $id_const, $id_punct) = (0, 0, 0, 0, 0);

foreach my $token (@{$lexer->{KeywordsTokenList}}) {
    $unique_keywords{$token->{Text}} = $id_kw++ unless exists $unique_keywords{$token->{Text}};
}
foreach my $token (@{$lexer->{OperatorsTokenList}}) {
    $unique_operators{$token->{Text}} = $id_op++ unless exists $unique_operators{$token->{Text}};
}
foreach my $token (@{$lexer->{identifiersTokenList}}) {
    $unique_identifiers{$token->{Text}} = $id_var++ unless exists $unique_identifiers{$token->{Text}};
}
foreach my $token (@{$lexer->{ConstantsTokenList}}) {
    $unique_constants{$token->{Text}} = $id_const++ unless exists $unique_constants{$token->{Text}};
}
foreach my $token (@{$lexer->{PunctuationsTokenList}}) {
    $unique_punctuations{$token->{Text}} = $id_punct++ unless exists $unique_punctuations{$token->{Text}};
}

sub get_token_id {
    my ($class, $text) = @_;
    if ($class eq "keyword")    { return exists $unique_keywords{$text} ? "$class:" . $unique_keywords{$text} : ""; }
    if ($class eq "operator")   { return exists $unique_operators{$text} ? "$class:" . $unique_operators{$text} : ""; }
    if ($class eq "identifier") { return exists $unique_identifiers{$text} ? "$class:" . $unique_identifiers{$text} : ""; }
    if ($class eq "constant")   { return exists $unique_constants{$text} ? "$class:" . $unique_constants{$text} : ""; }
    if ($class eq "punctuation"){ return exists $unique_punctuations{$text} ? "$class:" . $unique_punctuations{$text} : ""; }
    return "";
}

foreach my $token (@{$lexer->{TokenList}}) {
    my $token_id = get_token_id($token->{Class}, $token->{Text});
    print $main_fh sprintf("%-30s %-15s %-10d %-10d %-5s\n", $token->{Text}, $token->{Name}, $token->{Line}, $token->{Column}, $token_id);
}

sub print_unique_tokens {
    my ($fh, $unique_hash_ref, $class_name) = @_;
    print $fh sprintf("%-5s %-30s\n", "ID", "Лексема");
    print $fh "==================================\n";
    foreach my $text (sort { $unique_hash_ref->{$a} <=> $unique_hash_ref->{$b} } keys %{$unique_hash_ref}) {
        print $fh sprintf("%-5s %-30s\n", $unique_hash_ref->{$text}, $text);
    }
}

print_unique_tokens($keywords_fh, \%unique_keywords, "keyword");
print_unique_tokens($operators_fh, \%unique_operators, "operator");
print_unique_tokens($identifiers_fh, \%unique_identifiers, "identifier");
print_unique_tokens($constants_fh, \%unique_constants, "constant");
print_unique_tokens($punctuations_fh, \%unique_punctuations, "punctuation");

close($main_fh);
close($keywords_fh);
close($operators_fh);
close($identifiers_fh);
close($constants_fh);
close($punctuations_fh);
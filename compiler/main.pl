use strict;
use warnings;
use Data::Dumper;
use JSON;

use lib '../lib';
use Lexer;
use Parser;

our $index = 0;
our %ids;

my $filename = '../test-code/test-1/test.go';

open(my $fh, '<', $filename) or die "Не удалось открыть файл '$filename': $!";
my $code = do { local $/; <$fh> };
close($fh);

my $lexer = Lexer->new($code);
my $tokens = $lexer->lex_analyze();

print "Tokens: ", Dumper($tokens);
print "\n-----------------------------------------\n";

# $tokens получены из лексера
my $parser = Parser->new($tokens);
my $ast = $parser->parse();


print "Распознанные токены:\n";
foreach my $token (@$tokens) {
    print "Name: $token->{Name}, Text: '$token->{Text}', Line: $token->{Line}, Column: $token->{Column}\n";
}



print "Сгенерированное AST:\n", Dumper($ast);

# Преобразуем структуру в JSON с отступами
my $json = to_json($ast, { 
    pretty => 1,
    canonical => 1,
});

# Открываем файл для записи
my $filename1 = 'ast.json';
open(my $fh1, '>', $filename1) or die "Не удалось открыть файл '$filename1' для записи: $!";

# Записываем JSON в файл
print $fh1 $json;

# Закрываем файл
close($fh1);

print "Данные успешно записаны в файл '$filename1'.\n";



my $output_dir = 'results';
unless(-d $output_dir) {
    mkdir $output_dir or die "Не удалось создать директорию '$output_dir': $!";
}

open(my $main_fh,         '>', "$output_dir/result.txt")       or die "Не удалось создать файл result.txt: $!";
open(my $keywords_fh,     '>', "$output_dir/keywords.txt")     or die "Не удалось создать файл keywords.txt: $!";
open(my $operators_fh,    '>', "$output_dir/operators.txt")    or die "Не удалось создать файл operators.txt: $!";
open(my $identifiers_fh,    '>', "$output_dir/identifiers.txt")    or die "Не удалось создать файл identifiers.txt: $!";
open(my $constants_fh,    '>', "$output_dir/constants.txt")    or die "Не удалось создать файл constants.txt: $!";
open(my $punctuations_fh, '>', "$output_dir/punctuations.txt") or die "Не удалось создать файл punctuations.txt: $!";


my $header    = sprintf("%-35s %-24s %-15s %-20s %-10s\n", "Лексема", "Токен", "Строка", "Столбец", "ID");
my $separator = "=================================================================================\n";


print $main_fh $header, $separator;

my (%unique_keywords, %unique_operators, %unique_identifiers, %unique_constants, %unique_punctuations);
my ($id_kw, $id_op, $id_var, $id_const, $id_punct) = (0, 0, 0, 0, 0, 0);

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

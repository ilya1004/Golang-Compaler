package BuiltInFunctions;

use strict;
use warnings;

# Хэш для хранения сигнатур функций стандартных пакетов
our %FUNCTIONS = (
    'builtin' => {
        'append' => {
            params => [
                { name => 'slice', type => '[]T', param_pos => 0 },
                { name => 'elems', type => '...T', param_pos => 1 }
            ],
            return_types => ['[]T'],
            pos => 0
        },
        'cap' => {
            params => [
                { name => 'v', type => 'Type', param_pos => 0 }
            ],
            return_types => ['int'],
            pos => 0
        },
        'clear' => {
            params => [
                { name => 't', type => '[]T | map[Type]Type1', param_pos => 0 }
            ],
            return_types => [],
            pos => 0
        },
        'close' => {
            params => [
                { name => 'c', type => 'chan<- Type', param_pos => 0 }
            ],
            return_types => [],
            pos => 0
        },
        'complex' => {
            params => [
                { name => 'r', type => 'FloatType', param_pos => 0 },
                { name => 'i', type => 'FloatType', param_pos => 1 }
            ],
            return_types => ['ComplexType'],
            pos => 0
        },
        'copy' => {
            params => [
                { name => 'dst', type => '[]T', param_pos => 0 },
                { name => 'src', type => '[]T', param_pos => 1 }
            ],
            return_types => ['int'],
            pos => 0
        },
        'delete' => {
            params => [
                { name => 'm', type => 'map[Type]Type1', param_pos => 0 },
                { name => 'key', type => 'Type', param_pos => 1 }
            ],
            return_types => [],
            pos => 0
        },
        'imag' => {
            params => [
                { name => 'c', type => 'ComplexType', param_pos => 0 }
            ],
            return_types => ['FloatType'],
            pos => 0
        },
        'len' => {
            params => [
                { name => 'v', type => 'Type', param_pos => 0 }
            ],
            return_types => ['int'],
            pos => 0
        },
        'make' => {
            params => [
                { name => 't', type => 'Type', param_pos => 0 },
                { name => 'size', type => '...IntegerType', param_pos => 1 }
            ],
            return_types => ['Type'],
            pos => 0
        },
        'max' => {
            params => [
                { name => 'x', type => 'T', param_pos => 0 },
                { name => 'y', type => '...T', param_pos => 1 }
            ],
            return_types => ['T'],
            pos => 0
        },
        'min' => {
            params => [
                { name => 'x', type => 'T', param_pos => 0 },
                { name => 'y', type => '...T', param_pos => 1 }
            ],
            return_types => ['T'],
            pos => 0
        },
        'new' => {
            params => [
                { name => 'Type', type => 'Type', param_pos => 0 }
            ],
            return_types => ['*Type'],
            pos => 0
        },
        'panic' => {
            params => [
                { name => 'v', type => 'interface{}', param_pos => 0 }
            ],
            return_types => [],
            pos => 0
        },
        'print' => {
            params => [
                { name => 'args', type => '...Type', param_pos => 0 }
            ],
            return_types => [],
            pos => 0
        },
        'println' => {
            params => [
                { name => 'args', type => '...Type', param_pos => 0 }
            ],
            return_types => [],
            pos => 0
        },
        'real' => {
            params => [
                { name => 'c', type => 'ComplexType', param_pos => 0 }
            ],
            return_types => ['FloatType'],
            pos => 0
        },
        'recover' => {
            params => [],
            return_types => ['interface{}'],
            pos => 0
        }
    },
    'fmt' => {
        'Errorf' => {
            params => [
                { name => 'format', type => 'string', param_pos => 0 },
                { name => 'a', type => '...interface{}', param_pos => 1 }
            ],
            return_types => ['error'],
            pos => 0
        },
        'Fprint' => {
            params => [
                { name => 'w', type => 'io.Writer', param_pos => 0 },
                { name => 'a', type => '...interface{}', param_pos => 1 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Fprintf' => {
            params => [
                { name => 'w', type => 'io.Writer', param_pos => 0 },
                { name => 'format', type => 'string', param_pos => 1 },
                { name => 'a', type => '...interface{}', param_pos => 2 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Fprintln' => {
            params => [
                { name => 'w', type => 'io.Writer', param_pos => 0 },
                { name => 'a', type => '...interface{}', param_pos => 1 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Fscan' => {
            params => [
                { name => 'r', type => 'io.Reader', param_pos => 0 },
                { name => 'a', type => '...interface{}', param_pos => 1 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Fscanf' => {
            params => [
                { name => 'r', type => 'io.Reader', param_pos => 0 },
                { name => 'format', type => 'string', param_pos => 1 },
                { name => 'a', type => '...interface{}', param_pos => 2 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Fscanln' => {
            params => [
                { name => 'r', type => 'io.Reader', param_pos => 0 },
                { name => 'a', type => '...interface{}', param_pos => 1 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Print' => {
            params => [
                { name => 'a', type => '...interface{}', param_pos => 0 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Printf' => {
            params => [
                { name => 'format', type => 'string', param_pos => 0 },
                { name => 'a', type => '...interface{}', param_pos => 1 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Println' => {
            params => [
                { name => 'a', type => '...interface{}', param_pos => 0 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Scan' => {
            params => [
                { name => 'a', type => '...interface{}', param_pos => 0 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Scanf' => {
            params => [
                { name => 'format', type => 'string', param_pos => 0 },
                { name => 'a', type => '...interface{}', param_pos => 1 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Scanln' => {
            params => [
                { name => 'a', type => '...interface{}', param_pos => 0 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Sprint' => {
            params => [
                { name => 'a', type => '...interface{}', param_pos => 0 }
            ],
            return_types => ['string'],
            pos => 0
        },
        'Sprintf' => {
            params => [
                { name => 'format', type => 'string', param_pos => 0 },
                { name => 'a', type => '...interface{}', param_pos => 1 }
            ],
            return_types => ['string'],
            pos => 0
        },
        'Sprintln' => {
            params => [
                { name => 'a', type => '...interface{}', param_pos => 0 }
            ],
            return_types => ['string'],
            pos => 0
        },
        'Sscan' => {
            params => [
                { name => 'str', type => 'string', param_pos => 0 },
                { name => 'a', type => '...interface{}', param_pos => 1 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Sscanf' => {
            params => [
                { name => 'str', type => 'string', param_pos => 0 },
                { name => 'format', type => 'string', param_pos => 1 },
                { name => 'a', type => '...interface{}', param_pos => 2 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        },
        'Sscanln' => {
            params => [
                { name => 'str', type => 'string', param_pos => 0 },
                { name => 'a', type => '...interface{}', param_pos => 1 }
            ],
            return_types => ['int', 'error'],
            pos => 0
        }
    },
);

1;
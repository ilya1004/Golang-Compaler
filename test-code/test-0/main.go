package main

import (
	"fmt"
)

const WelcomeMessage = "Добро пожаловать в калькулятор на Go!"
const ErrorMessage = "Ошибка: неверный ввод!"

func calculate(a, b float64, operation string) float64 {
	println("qweweqwe")
	println(a)
	println(b)
	switch operation {
	case "+":
		return a + b
	case "-":
		return a - b
	case "*":
		return a * b
	case "/":
		if b != 0 {
			return a / b
		}
		// fmt.Println(ErrorMessage)
		return 0
	default:
		// fmt.Println(ErrorMessage)
		return 0
	}
}

func main() {
	var num1 float64
	var num2 float64

	var operation string

	fmt.Println(WelcomeMessage)
	fmt.Print("Введите первое число: ")
	fmt.Scan(&num1)
	fmt.Print("Введите второе число: ")
	fmt.Scan(&num2)
	fmt.Print("Введите операцию (+, -, *, /): ")
	fmt.Scan(&operation)
	println("qweqwe")

	println(operation)
	println(len(operation))

	if operation == "+" {
		println("qweqwe")
	}

	if operation == "+" || operation == "-" || operation == "*" || operation == "/" {

		// println(num1)
		// println(num2)
		println(operation)

		result := calculate(num1, num2, operation)
		fmt.Printf("Результат: %.2f\n", result)
	} else {
		fmt.Println(ErrorMessage)
	}
}

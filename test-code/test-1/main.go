package main

import (
	"fmt"
)

const WelcomeMessage = "Добро пожаловать в калькулятор на Go!"
const ErrorMessage = "Ошибка: неверный ввод!"

func calculate(a, b float64, operation string) float64 {
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
		fmt.Println(ErrorMessage)
		return 0
	default:
		fmt.Println(ErrorMessage)
		return 0
	}
}

func main() {
	var num1, num2 float64

	var operation string

	var flag bool = false

	qwe := num1 + num2
	fmt.Println(qwe)
	flag1 := true
	flag = true

	fmt.Print(flag)
	fmt.Print(flag1)

	fmt.Println(WelcomeMessage)
	fmt.Print("Введите первое число: ")
	fmt.Scan(&num1)
	fmt.Print("Введите второе число: ")
	fmt.Scan(&num2)
	fmt.Print("Введите операцию (+, -, *, /): ")
	fmt.Scan(&operation)

	if operation == "+" || operation == "-" || operation == "*" || operation == "/" {
		result := calculate(num1, num2, operation)
		fmt.Printf("Результат: %.2f\n", result)
	} else {
		fmt.Println(ErrorMessage)
	}
}

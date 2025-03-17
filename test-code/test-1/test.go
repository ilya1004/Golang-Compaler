package main

import "fmt"

func main() {
	// Цикл с инициализацией, условием и итерацией
	// for i := 0; i < 5; i++ {
	// 	fmt.Println("Цикл 1:", i)
	// }

	// Цикл с условием
	// j := 0
	// for j < 5 {
	// 	fmt.Println("Цикл 2:", j)
	// 	j++
	// }

	// Бесконечный цикл (работаеты)
	// k := 0
	// for {
	// 	if k == 5 {
	// 		break
	// 	}
	// 	fmt.Println("Цикл 3:", k)
	// 	k++
	// }

	// Цикл с использованием range
	// arr := []int{1, 2, 3, 4, 5}
	for index, value := range arr {
		fmt.Printf("Индекс: %d, Значение: %d\n", index, value)
	}
}

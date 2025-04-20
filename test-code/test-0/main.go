package main

type Sequence struct {
	Start int
	End   int
	Step  int
}

func generateSequence(seq Sequence) []int {
	var result []int

	for i := seq.Start; i <= seq.End; i += seq.Step {
		result = append(result, i)
	}
	return result
}

// func main() {
// 	seq := Sequence{Start: 1, End: 10, Step: 2}

// 	i := 0
// 	fmt.Println("Генерация последовательности:")
// 	for {
// 		if i >= 3 {
// 			break
// 		}
// 		var numbers = generateSequence(seq)
// 		fmt.Println(numbers)
// 		i++
// 	}
// }

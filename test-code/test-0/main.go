package main

import (
	"fmt"
)

type Student struct {
	Name  string
	Grade int
}

func printStudentStatus(student Student) {
	if student.Grade >= 50 {
		fmt.Printf("Студент %s сдал экзамен с оценкой %d.\n", student.Name, student.Grade)
	} else {
		fmt.Printf("Студент %s не сдал экзамен с оценкой %d.\n", student.Name, student.Grade)
	}
}

func main() {
	students := []Student{
		{Name: "Иван", Grade: 75},
		{Name: "Мария", Grade: 45},
		{Name: "Анна", Grade: 90},
	}

	for _, student := range students {
		printStudentStatus(student)
	}
}

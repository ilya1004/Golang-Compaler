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
		{"Иван", 75},
		{"Мария", 45},
		{"Анна", 90},
	}

	for _, student := range students {
		printStudentStatus(student)
	}
}

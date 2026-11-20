package main

import (
	"os"
	"time"
)

func main() {
	os.Stdout.WriteString("Hello, World!\n")
	time.Sleep(1000 * time.Hour) // stay alive so Task Manager can see it
}


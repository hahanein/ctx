package main

import (
	"encoding/gob"
	"fmt"
	"os"
)

const usage = `
ctx - A git-style command line tool

Usage: ctx <command> [arguments]

Commands:
  init             Create new context
  add <file>...    Add files
  help             Show this help message
`

type Context struct {
	Files []string
}

func init() {
	gob.Register(Context{})
}

func main() {
	if len(os.Args) < 2 {
		fmt.Print(usage)
		os.Exit(1)
	}

	command := os.Args[1]

	switch command {
	case "init":
		if err := handleInit(); err != nil {
			fmt.Println(err)
			os.Exit(1)
		}
	case "add":
		handleAdd(os.Args[2:])
	case "help", "-h", "--help":
		fmt.Print(usage)
	default:
		fmt.Printf("Unknown command: %s\n", command)
		fmt.Print(usage)
		os.Exit(1)
	}
}

func handleAdd(args []string) {
	if len(args) == 0 {
		fmt.Println("Error: no files specified")
		fmt.Println("Usage: ctx add <file>...")
		os.Exit(1)
	}

	for _, file := range args {
		fmt.Printf("Adding file: %s\n", file)
	}
}

func handleInit() error {
	f, err := os.Create(".ctx")
	if err != nil {
		return err
	}

	return gob.NewEncoder(f).Encode(Context{})
}

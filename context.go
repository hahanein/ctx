package main

import (
	"encoding/gob"
	"os"
)

type Context struct {
	Files []string
}

func Init() error {
	return write(Context{})
}

func read() (Context, error) {
	res := Context{}

	f, err := os.Open(".ctx")
	if err != nil {
		return res, err
	}

	err = gob.NewDecoder(f).Decode(&res)

	return res, err
}

func write(ctx Context) error {
	f, err := os.Create(".ctx")
	if err != nil {
		return err
	}

	return gob.NewEncoder(f).Encode(ctx)
}

func Add(files ...string) error {
	ctx, err := read()
	if err != nil {
		return err
	}

	ctx.Files = append(ctx.Files, files...)

	return nil
}

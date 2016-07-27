package config

import (
	"io/ioutil"
	"path"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
)

func TestEcho(t *testing.T) {
	out := Echo("Hello\nWorld!")
	assert.Equal(t, "Hello", <-out)
	assert.Equal(t, "World!", <-out)
}

func TestHead(t *testing.T) {
	out := Head(Echo("Hello\nWorld!"), 2)
	assert.Equal(t, "Hello", <-out)
	assert.Equal(t, "World!", <-out)

	assert.Equal(t, 1, Wc(Head(Echo("Hello\nWorld!"), 1)))
	assert.Equal(t, 2, Wc(Head(Echo("Hello\nWorld!"), 2)))
	assert.Equal(t, 2, Wc(Head(Echo("Hello\nWorld!"), 3)))
}

func TestEach_ToFile_Cat_Du_Grep_ForEach(t *testing.T) {
	dir, e := ioutil.TempDir("", "")
	candy.Must(e)

	filename := path.Join(dir, "TestToFile")
	ToFile(Echo("Hello\nWorld!"), filename)

	out := Cat(filename)
	assert.Equal(t, "Hello", <-out)
	assert.Equal(t, "World!", <-out)

	assert.Equal(t, filename, <-Grep(Du(dir), "TestToFile"))

	assert.Equal(t, "Hello",
		<-For(Du(dir), func(filename string) chan string {
			return Grep(Cat(filename), "Hello")
		}))
}

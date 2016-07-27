package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestCmd(t *testing.T) {
	assert.NotPanics(t, func() { Cmd("ls", "/") })
	assert.Panics(t, func() { Cmd("something-not-exists", "/") })
}

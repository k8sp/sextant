package cmd

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRun(t *testing.T) {
	*Silent = true
	assert.NotPanics(t, func() { Run("ls", "/") })
	assert.Panics(t, func() { Run("something-not-exists", "/") })
}

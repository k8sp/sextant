package coreos

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetVersion(t *testing.T) {
	alpha := GetVersion("alpha")
	beta := GetVersion("beta")
	stable := GetVersion("stable")
	assert.True(t, strings.Compare(stable, beta) <= 0)
	assert.True(t, strings.Compare(beta, alpha) <= 0)
}

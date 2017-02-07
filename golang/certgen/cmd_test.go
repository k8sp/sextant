package certgen

import (
	"fmt"
	"io/ioutil"
	"path"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRunAndTry(t *testing.T) {
	*Silent = true
	assert.NotPanics(t, func() { Run("ls", "/") })
	assert.Panics(t, func() { Run("something-not-exists") })
	assert.NotPanics(t, func() { Try("something-not-exists") })
}

func TestRunWithEnv(t *testing.T) {
	tmpdir, _ := ioutil.TempDir("", "")
	tmpfile := path.Join(tmpdir, "TestRunWithEnv")

	RunWithEnv(map[string]string{"GOPATH": "/tmp"},
		"awk",
		fmt.Sprintf("BEGIN{print ENVIRON[\"GOPATH\"] > \"%s\";}", tmpfile))

	b, _ := ioutil.ReadFile(tmpfile)
	assert.Equal(t, "/tmp\n", string(b))
}

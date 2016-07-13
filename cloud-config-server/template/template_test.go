package template

import (
	"io"
	"io/ioutil"
	"os"
	"testing"
	"text/template"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func TestExecute(t *testing.T) {

	config := candy.WithOpened("build_config.yml", func(r io.Reader) interface{} {
		b, e := ioutil.ReadAll(r)
		candy.Must(e)

		c := &Config{}
		assert.Nil(t, yaml.Unmarshal(b, &c))
		return c
	}).(*Config)

	tmpl, e := template.ParseFiles("cloud-config.template")
	candy.Must(e)

	Execute(tmpl, config, "00:25:90:c0:f7:62", os.Stdout)
}

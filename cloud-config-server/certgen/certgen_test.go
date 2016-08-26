package certgen

import (
	"io/ioutil"
	"log"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
)

func TestGen(t *testing.T) {
	out, e := ioutil.TempDir("", "")
	candy.Must(e)
	defer func() {
		if e = os.RemoveAll(out); e != nil {
			log.Printf("Generator.Gen failed deleting %s", out)
		}
	}()
	caKey, caCrt := GenerateRootCA(out)
	key, crt := Gen(true, "10.10.10.201", caKey, caCrt)

	assert.True(t, strings.HasPrefix(string(key), "-----BEGIN RSA PRIVATE KEY-----"))
	assert.True(t, strings.HasSuffix(string(key), "-----END RSA PRIVATE KEY-----\n"))

	assert.True(t, strings.HasPrefix(string(crt), "-----BEGIN CERTIFICATE-----"))
	assert.True(t, strings.HasSuffix(string(crt), "-----END CERTIFICATE-----\n"))
}

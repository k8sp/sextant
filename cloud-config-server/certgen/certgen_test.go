package certgen

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
)

func TestGen(t *testing.T) {
	key, crt := Gen("192.168.1.1", "master", candy.TestData("ca.crt"), candy.TestData("ca.key"))

	assert.True(t, strings.HasPrefix(string(key), "-----BEGIN RSA PRIVATE KEY-----"))
	assert.True(t, strings.HasSuffix(string(key), "-----END RSA PRIVATE KEY-----\n"))

	assert.True(t, strings.HasPrefix(string(crt), "-----BEGIN CERTIFICATE-----"))
	assert.True(t, strings.HasSuffix(string(crt), "-----END CERTIFICATE-----\n"))
}

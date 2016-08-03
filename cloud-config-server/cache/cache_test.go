package cache

import (
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"path"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestCacheWithUpdate(t *testing.T) {
	srv := 0
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "%05d", srv)
		srv++
	})

	ln, e := net.Listen("tcp", ":0")
	assert.Nil(t, e)
	go http.Serve(ln, nil)

	url := fmt.Sprintf("http://%s/", ln.Addr())
	tmpdir, _ := ioutil.TempDir("", "")
	cache := New(url, path.Join(tmpdir, "cachefile"))

	for i := 0; i < 10; i++ {
		assert.Equal(t, fmt.Sprintf("%05d", i), string(cache.Get()))
		time.Sleep(50 * time.Millisecond)
	}
}

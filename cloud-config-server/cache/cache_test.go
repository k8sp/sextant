package cache

import (
	"fmt"
	"io/ioutil"
	"net"
	"net/http"
	"path"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
)

func TestCacheWithUpdate(t *testing.T) {
	mux := http.NewServeMux()
	srv := 0
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "%05d", srv)
		srv++
	})

	ln, e := net.Listen("tcp", ":0")
	assert.Nil(t, e)
	go func() {
		candy.Must(http.Serve(ln, mux))
	}()

	url := fmt.Sprintf("http://%s/", ln.Addr())
	tmpdir, _ := ioutil.TempDir("", "")
	cache := New(url, path.Join(tmpdir, "cachefile"))

	for i := 0; i < 10; i++ {
		assert.Equal(t, fmt.Sprintf("%05d", srv-1), string(cache.Get()))
	}
}

func TestCacheWithConstantServer(t *testing.T) {
	mux := http.NewServeMux()
	srv := 0
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if srv == 0 {
			fmt.Fprintf(w, "%05d", srv)
			srv++
		} else {
			http.Error(w, "no longer works", http.StatusInternalServerError)
		}
	})

	ln, e := net.Listen("tcp", ":0")
	assert.Nil(t, e)
	go func() {
		candy.Must(http.Serve(ln, mux))
	}()

	url := fmt.Sprintf("http://%s/", ln.Addr())
	tmpdir, _ := ioutil.TempDir("", "")
	cache := New(url, path.Join(tmpdir, "cachefile"))

	for i := 0; i < 10; i++ {
		assert.Equal(t, "00000", string(cache.Get()))
	}
}

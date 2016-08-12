package cache

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"path"
	"sync"
	"time"

	"github.com/topicai/candy"
)

// Cache manages a local in-memory copy of a remote file as well as a
// local on-disk copy.  It periodically read the remote file (which
// might change occasionally), update the local in-memory and on-disk
// copy.
//
// Example:
/*
func main() {
  c := cache.New(url, filename)
  http.Handle("/", handler)
}

func handler(...) {
  c.Get() // returns cache content and triggers update. No waiting.
}
*/
type Cache struct {
	filename string
	url      string
	content  []byte
	mu       sync.Mutex // protects RW of content.

	update chan int // Writing into this channel tiggers an update.
	close  chan int // Writing into this channel closes the cache.
}

const (
	loadTimeout  = 15 * time.Second
	updatePeriod = 20 * time.Second
)

// New panics if it fails to read remote nor local file; othersie it
// returns a ready-to-read in-memory cache.  To close the cache and
// free all resources, write into channel Cache.close.
func New(url, filename string) *Cache {
	c := &Cache{
		filename: filename,
		url:      url,
		content:  load(url, filename),
		update:   make(chan int, 1),
		close:    make(chan int),
	}

	go func() {
		if len(c.url) == 0 {
			return // No periodic update if url is empty.
		}

		tic := time.Tick(updatePeriod)
		for {
			select {
			case <-c.close:
				close(c.update)
				close(c.close)
				return
			default:
			}

			log.Printf("Cache updating %s / %s", c.url, c.filename)
			if b, e := httpGet(c.url, loadTimeout); e == nil {
				c.mu.Lock()
				c.content = b
				c.mu.Unlock()

				if e := ioutil.WriteFile(c.filename, b, 0644); e != nil {
					log.Printf("Cannot write to local file %s: %v", c.filename, e)
				}
			}

			select {
			case <-tic:
			case <-c.update:
			}
		}
	}()

	return c
}

// load panics if cannot read remote nor local file.
func load(url, fn string) []byte {
	var (
		b []byte
		e error
	)
	if len(url) > 0 {
		log.Printf("Try loading from %s...", url)
		b, e = httpGet(url, loadTimeout)
	}
	if e != nil || len(url) == 0 {
		log.Printf("Try loading from %s...", fn)
		b, e = ioutil.ReadFile(fn)
	}
	if e != nil {
		log.Panicf("Cannot load neither remotely nor locally.")
	}
	return b
}

func httpGet(url string, timeout time.Duration) ([]byte, error) {
	client := http.Client{
		Timeout: timeout,
	}
	resp, err := client.Get(url)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("Expecting StatusCode 200, but got %d", resp.StatusCode)
	}

	defer func() {
		candy.Must(resp.Body.Close())
	}()

	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Printf("%v", err)
		return nil, err
	}
	return body, nil
}

// Get returns content in memory, and triggers an update without waiting.
func (c *Cache) Get() []byte {
	b := make([]byte, len(c.content))
	c.mu.Lock()
	copy(b, c.content)
	c.mu.Unlock()

	select {
	case c.update <- 1:
	default:
	}

	return b
}

// Close closes the cache and release all resources.
func (c *Cache) Close() {
	c.close <- 1
}

// MakeCacheGetter returns a closure for get a cache
func MakeCacheGetter(url, fn string) func() []byte {
	if len(fn) == 0 {
		dir, e := ioutil.TempDir("", "")
		candy.Must(e)
		fn = path.Join(dir, "localfile")
	}
	c := New(url, fn)
	return func() []byte { return c.Get() }
}

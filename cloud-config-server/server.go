// cloud-config-server starts an HTTP server, which can be accessed
// via URLs in the form of
//
//   http://<addr:port>?mac=aa:bb:cc:dd:ee:ff
//
// and returns the cloud-config YAML file specificially tailored for
// the node whose primary NIC's MAC address matches that specified in
// above URL.
package main

import (
	"errors"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"path"
	"strings"
	"text/template"

	"github.com/gorilla/mux"
	"github.com/k8sp/sextant/cloud-config-server/cache"
	"github.com/k8sp/sextant/cloud-config-server/certgen"
	cctemplate "github.com/k8sp/sextant/cloud-config-server/template"
	"github.com/k8sp/sextant/clusterdesc"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func main() {
	clusterDescURL := flag.String("cluster-desc-url",
		"https://raw.githubusercontent.com/k8sp/sextant/master/cloud-config-server/template/unisound-ailab/build_config.yml",
		"URL to remote cluster description YAML file.")
	clusterDescFile := flag.String("cluster-desc-file", "./cluster-desc.yml", "Local copy of cluster description YAML file.")

	ccTemplateURL := flag.String("cc-template-url",
		"https://raw.githubusercontent.com/k8sp/sextant/master/cloud-config-server/template/cloud-config.template",
		"URL to cloud-config file template.")
	ccTemplateFile := flag.String("cc-template-file", "./cloud-config.template", "Local copy of cloud-config file template.")

	caCrt := flag.String("ca-crt", "", "CA certificate file, in PEM format")
	caKey := flag.String("ca-key", "", "CA private key file, in PEM format")
	addr := flag.String("addr", ":8080", "Listening address")

	dir := flag.String("dir", "./static/", "The directory to serve files from. Default is ./static/")

	flag.Parse()

	if len(*caCrt) == 0 || len(*caKey) == 0 {
		*caKey, *caCrt = certgen.GenerateRootCA("./")
	}
	// valid caKey and caCrt file is ready
	candy.Must(fileExist(*caCrt))
	candy.Must(fileExist(*caKey))

	c := makeCacheGetter(*clusterDescURL, *clusterDescFile)
	t := makeCacheGetter(*ccTemplateURL, *ccTemplateFile)

	l, e := net.Listen("tcp", *addr)
	candy.Must(e)
	run(c, t, l, *caKey, *caCrt, *dir)
}

// By making the first two parameters closures, we get the flexibility
// to create closures reading from the cache for production serving,
// and from constant values for testing.  Please refer to func main()
// for the former case, and server_test.go for the latter case.
func run(clusterDesc func() []byte, ccTemplate func() []byte, ln net.Listener, caKey, caCrt, dir string) {
	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/cloud-config/{mac}",
		makeSafeHandler(func(w http.ResponseWriter, r *http.Request) {
			mac := strings.ToLower(mux.Vars(r)["mac"])
			tmpl := template.Must(template.New("template").Parse(string(ccTemplate())))
			c := &clusterdesc.Cluster{}
			candy.Must(yaml.Unmarshal(clusterDesc(), c))
			candy.Must(cctemplate.Execute(tmpl, c, mac, caKey, caCrt, w))
		}))
	router.PathPrefix("/static/").Handler(http.StripPrefix("/static/", http.FileServer(http.Dir(dir))))

	log.Printf("%v", http.Serve(ln, router))
}

func makeSafeHandler(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		defer func() {
			if err := recover(); err != nil {
				http.Error(w, fmt.Sprint(err), http.StatusInternalServerError)
			}
		}()
		h(w, r)
	}
}

func makeCacheGetter(url, fn string) func() []byte {
	if len(fn) == 0 {
		dir, e := ioutil.TempDir("", "")
		candy.Must(e)
		fn = path.Join(dir, "localfile")
	}
	c := cache.New(url, fn)
	return func() []byte { return c.Get() }
}

func fileExist(fn string) error {
	_, err := os.Stat(fn)
	if err != nil || os.IsNotExist(err) {
		return errors.New("file " + fn + " is not ready.")
	}
	return nil
}

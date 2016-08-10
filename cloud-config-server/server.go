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
	"bytes"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"path"
	"strings"
	"text/template"

	"github.com/gorilla/mux"
	"github.com/k8sp/auto-install/cloud-config-server/cache"
	"github.com/k8sp/auto-install/cloud-config-server/certgen"
	cctemplate "github.com/k8sp/auto-install/cloud-config-server/template"
	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func main() {
	clusterDescURL := flag.String("cluster-desc-url",
		"https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/unisound-ailab/build_config.yml",
		"URL to remote cluster description YAML file.")
	clusterDescFile := flag.String("cluster-desc-file", "./cluster-desc.yml", "Local copy of cluster description YAML file.")

	ccTemplateURL := flag.String("cc-template-url",
		"https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/cloud-config.template",
		"URL to cloud-config file template.")
	ccTemplateFile := flag.String("cc-template-file", "./cloud-config.template", "Local copy of cloud-config file template.")

	caCrt := flag.String("ca-crt", "", "CA certificate file, in PEM format")
	caKey := flag.String("ca-key", "", "CA private key file, in PEM format")
	addr := flag.String("addr", ":8080", "Listening address")

	flag.Parse()

	if len(*caCrt) == 0 || len(*caKey) == 0 {
		fmt.Printf("ca-crt and ca-key should not be empty. Usage: \n\n")
		flag.PrintDefaults()
		return
	}
	c := makeCacheGetter(*clusterDescURL, *clusterDescFile)
	t := makeCacheGetter(*ccTemplateURL, *ccTemplateFile)

	l, e := net.Listen("tcp", *addr)
	candy.Must(e)
	run(c, t, l, *caCrt, *caKey)
}

// By making the first two parameters closures, we get the flexibility
// to create closures reading from the cache for production serving,
// and from constant values for testing.  Please refer to func main()
// for the former case, and server_test.go for the latter case.
func run(clusterDesc func() []byte, ccTemplate func() []byte, ln net.Listener, caCrt, caKey string) {
	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/cloud-config/{mac}",
		makeSafeHandler(func(w http.ResponseWriter, r *http.Request) {
			mac := strings.ToLower(mux.Vars(r)["mac"])
			tmpl := template.Must(template.New("template").Parse(string(ccTemplate())))
			c := &config.Cluster{}
			candy.Must(yaml.Unmarshal(clusterDesc(), c))
			candy.Must(cctemplate.Execute(tmpl, c, mac, w))
		}))

	router.HandleFunc("/tls/{role}/{ip}/",
		makeSafeHandler(func(w http.ResponseWriter, r *http.Request) {
			role := strings.ToLower(mux.Vars(r)["role"])
			ip := mux.Vars(r)["ip"]
			crt, key := certgen.Gen(ip, role, caCrt, caKey)
			_, e := w.Write(makeCertData(crt, key, caCrt))
			candy.Must(e)
		}))

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

func makeCertData(crt, key []byte, caCrt string) []byte {
	ca, e := ioutil.ReadFile(caCrt)
	candy.Must(e)

	var buffer bytes.Buffer
	buffer.Write(crt)
	buffer.WriteString("<>")
	buffer.Write(key)
	buffer.WriteString("<>")
	buffer.Write(ca)
	buffer.WriteString("<>")
	return buffer.Bytes()
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

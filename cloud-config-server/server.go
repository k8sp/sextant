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
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"strings"
	"text/template"

	"github.com/gorilla/mux"
	"github.com/k8sp/auto-install/cache"
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
		"URL to remote cloud-config file template.")
	ccTemplateFile := flag.String("cc-template-file", "./cloud-config.template", "Local copy of cloud-config file template.")

	addr := flag.String("addr", ":8080", "Listening address")
	flag.Parse()

	c := cache.MakeCacheGetter(*clusterDescURL, *clusterDescFile)
	t := cache.MakeCacheGetter(*ccTemplateURL, *ccTemplateFile)
	l, e := net.Listen("tcp", *addr)
	candy.Must(e)
	run(c, t, l)
}

// By making the first two parameters closures, we get the flexibility
// to create closures reading from the cache for production serving,
// and from constant values for testing.  Please refer to func main()
// for the former case, and server_test.go for the latter case.
func run(clusterDesc func() []byte, ccTemplate func() []byte, ln net.Listener) {
	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/cloud-config/{mac}",
		makeSafeHandler(func(w http.ResponseWriter, r *http.Request) {
			mac := strings.ToLower(mux.Vars(r)["mac"])
			tmpl := template.Must(template.New("template").Parse(string(ccTemplate())))
			c := &config.Cluster{}
			candy.Must(yaml.Unmarshal(clusterDesc(), c))
			candy.Must(cctemplate.Execute(tmpl, c, mac, w))
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

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
	"io/ioutil"
	"log"
	"net/http"
	"path"
	"strings"
	"text/template"

	"github.com/gorilla/mux"
	"github.com/k8sp/auto-install/cloud-config-server/cache"
	cctemplate "github.com/k8sp/auto-install/cloud-config-server/template"
	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
)

func main() {
	clusterDesc := flag.String("cluster-desc",
		"https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/unisound-ailab/build_config.yml",
		"URL to cluster description YAML file.")
	ccTemplate := flag.String("cc-template",
		"https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/cloud-config.template",
		"URL to cloud-config file template.")
	addr := flag.String("addr", ":8080", "Listening address")
	flag.Parse()

	run(*clusterDesc, *ccTemplate, *addr)
}

func run(clusterDesc, ccTemplate, listenAddr string) {
	dir, e := ioutil.TempDir("", "")
	candy.Must(e)
	clusterCache := cache.New(clusterDesc, path.Join(dir, "cluster-desc.yml"))
	templCache := cache.New(ccTemplate, path.Join(dir, "cloud-config.template"))

	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/cloud-config/{mac}",
		makeSafeHandler(func(w http.ResponseWriter, r *http.Request) {
			mac := strings.ToLower(mux.Vars(r)["mac"])
			tmpl := template.Must(template.New("template").Parse(string(templCache.Get())))
			c := &config.Cluster{}
			candy.Must(yaml.Unmarshal([]byte(string(clusterCache.Get())), c))
			candy.Must(cctemplate.Execute(tmpl, c, mac, w))
		}))
	log.Printf("%v", http.ListenAndServe(listenAddr, router))
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

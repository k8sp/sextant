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
	"net"
	"net/http"
	"path"
	"strings"
	"text/template"

	"github.com/gorilla/mux"
	"github.com/k8sp/auto-install/cloud-config-server/cache"
	cctemplate "github.com/k8sp/auto-install/cloud-config-server/template"
	"github.com/k8sp/auto-install/cloud-config-server/tls"
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
	caPem := flag.String("ca", "", "Root CA Cert, such as ca.pem")
	caKeyPem := flag.String("ca-key", "", "Root CA Key, such as ca-key.pem")
	addr := flag.String("addr", ":8080", "Listening address")

	flag.Parse()

	if len(*caPem) == 0 || len(*caKeyPem) == 0 {
		fmt.Printf("ca and ca-key should not be empty. Usage: \n\n")
		flag.PrintDefaults()
		return
	}
	c, t := makeCacheGetter(*clusterDesc, *ccTemplate)
	l, e := net.Listen("tcp", *addr)
	tls := tls.Tls{
		CAPem:    *caPem,
		CAKeyPem: *caKeyPem,
	}
	candy.Must(e)
	run(c, t, l, tls)
}

// By making the first two parameters closures, we get the flexibility
// to create closures reading from the cache for production serving,
// and from constant values for testing.  Please refer to func main()
// for the former case, and server_test.go for the latter case.
func run(clusterDesc func() []byte, ccTemplate func() string, ln net.Listener,
	tls tls.Tls) {
	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/cloud-config/{mac}",
		makeSafeHandler(func(w http.ResponseWriter, r *http.Request) {
			mac := strings.ToLower(mux.Vars(r)["mac"])
			tmpl := template.Must(template.New("template").Parse(ccTemplate()))
			c := &config.Cluster{}
			candy.Must(yaml.Unmarshal(clusterDesc(), c))
			candy.Must(cctemplate.Execute(tmpl, c, mac, w))
		}))

	router.HandleFunc("/tls/{role}/{ip}/",
		makeSafeHandler(func(w http.ResponseWriter, r *http.Request) {
			role := strings.ToLower(mux.Vars(r)["role"])
			ip := mux.Vars(r)["ip"]
			data, err := tls.GenerateCerts(role, ip)
			if err != nil {
				w.Write([]byte("Error"))
			} else {
				w.Write([]byte(data))
			}
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

func makeCacheGetter(clusterDesc, ccTemplate string) (func() []byte, func() string) {
	dir, e := ioutil.TempDir("", "")
	candy.Must(e)
	clusterCache := cache.New(clusterDesc, path.Join(dir, "cluster-desc.yml"))
	templCache := cache.New(ccTemplate, path.Join(dir, "cloud-config.template"))

	c := func() []byte { return clusterCache.Get() }
	t := func() string { return string(templCache.Get()) }
	return c, t
}

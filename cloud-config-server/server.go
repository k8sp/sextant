package main

import (
	"flag"
	"fmt"
	"log"
	"net/http"
	"strings"
	"text/template"

	"github.com/gorilla/mux"
	"github.com/k8sp/auto-install/cloud-config-server/cache"
	tp "github.com/k8sp/auto-install/cloud-config-server/template"
	tpcfg "github.com/k8sp/auto-install/config"
	"gopkg.in/yaml.v2"
)

var templateURL = "https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/cloud-config.template?token=ABVwef_01-UjZGXlw2ZXgCKfZM58UEsyks5XnquFwA%3D%3D"
var configURL = "https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/unisound-ailab/build_config.yml?token=ABVwec2SvquxRR_h9JF-9Rg8RvuuWjcpks5XnqyawA%3D%3D"
var configCache *cache.Cache
var templCache *cache.Cache

func main() {
	flag.StringVar(&configURL, "configURL", "https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/unisound-ailab/build_config.yml?token=ABVwec2SvquxRR_h9JF-9Rg8RvuuWjcpks5XnqyawA%3D%3D", "cluster config yaml file url")
	flag.StringVar(&templateURL, "templateURL", "https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/cloud-config.template?token=ABVwef_01-UjZGXlw2ZXgCKfZM58UEsyks5XnquFwA%3D%3D", "cloud-config template url")
	flag.Parse()

	configCache = cache.New(configURL, "./cluster-desc.yml")
	templCache = cache.New(templateURL, "./cloud-config.template")

	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/cloud-config/{mac}", HTTPHandler)
	log.Printf("%v\n", http.ListenAndServe(":8080", router))
}

// HTTPHandler process http request.
func HTTPHandler(w http.ResponseWriter, r *http.Request) {
	defer func() {
		if err := recover(); err != nil {
			http.Error(w, fmt.Sprint(err), http.StatusInternalServerError)
		}
	}()

	vars := mux.Vars(r)

	mac := strings.ToLower(vars["mac"])
	mac = strings.Replace(mac, ".yml", "", -1)
	mac = strings.Replace(mac, ":", "-", -1)

	config := string(configCache.Get())
	templ := string(templCache.Get())

	if templ == "" || config == "" {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("SERVER ERROR!\n"))
		return
	}

	tpl := template.Must(template.New("template").Parse(templ))
	cfg := &tpcfg.Cluster{}
	yaml.Unmarshal([]byte(config), &cfg)
	tp.Execute(tpl, cfg, mac, w)
}

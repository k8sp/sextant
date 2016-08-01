package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"strings"
	"text/template"
	"time"

	"github.com/gorilla/mux"
	tp "github.com/k8sp/auto-install/cloud-config-server/template"
	tpcfg "github.com/k8sp/auto-install/config"
	"gopkg.in/yaml.v2"
)

var template_url = "https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/cloud-config.template?token=ABVwef_01-UjZGXlw2ZXgCKfZM58UEsyks5XnquFwA%3D%3D"
var config_url = "https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/unisound-ailab/build_config.yml?token=ABVwec2SvquxRR_h9JF-9Rg8RvuuWjcpks5XnqyawA%3D%3D"

func init() {
	ticker := time.NewTicker(time.Minute * 10)
	go func() {
		for _ = range ticker.C {
			template, config, err := RetriveFromGithub(5 * time.Second)
			if err != nil {
				template = ""
				config = ""
				continue
			}
			WriteToFile(template, config)
		}
	}()
}

func main() {
	flag.StringVar(&config_url, "config_url", "https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/unisound-ailab/build_config.yml?token=ABVwec2SvquxRR_h9JF-9Rg8RvuuWjcpks5XnqyawA%3D%3D", "cluster config yaml file url")
	flag.StringVar(&template_url, "template_url", "https://raw.githubusercontent.com/k8sp/auto-install/master/cloud-config-server/template/cloud-config.template?token=ABVwef_01-UjZGXlw2ZXgCKfZM58UEsyks5XnquFwA%3D%3D", "cloud-config template url")
	flag.Parse()

	router := mux.NewRouter().StrictSlash(true)
	router.HandleFunc("/cloud-config/{mac}", HttpHandler)
	log.Printf("%v\n", http.ListenAndServe(":8080", router))
}

func HttpHandler(w http.ResponseWriter, r *http.Request) {
	defer func() {
		if err := recover(); err != nil {
			http.Error(w, fmt.Sprint(err), http.StatusInternalServerError)
		}
	}()

	vars := mux.Vars(r)

	mac := strings.ToLower(vars["mac"])
	mac = strings.Replace(mac, ".yml", "", -1)
	mac = strings.Replace(mac, ":", "-", -1)

	templ, config, err := RetriveFromGithub(3 * time.Second)
	if err != nil {
		templ, config, err = ReadFromFile()
		if err != nil {
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
	} else {
		WriteToFile(templ, config)
	}

	if templ == "" || config == "" {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("SERVER ERROR!\n"))
		return

	}
	tpl := template.Must(template.New("template").Parse(templ))
	cfg := &tpcfg.Cluster{}
	err = yaml.Unmarshal([]byte(config), &cfg)
	tp.Execute(tpl, cfg, mac, w)
}

func RetriveFromGithub(timeout time.Duration) (template string, config string, err error) {
	template, err = httpGet(template_url, timeout)
	if err != nil {
		log.Printf("%v\n", err)
		return "", "", err
	}
	config, err = httpGet(config_url, timeout)
	if err != nil {
		log.Printf("%v\n", err)
		return "", "", err
	}
	return template, config, nil
}

func WriteToFile(template string, config string) {
	if template == "" || config == "" {
		return
	}
	tplFile := "./template/cloud-config.template"
	cfgFile := "./template/unisound-ailab/build_config.yml"
	ioutil.WriteFile(tplFile, []byte(template), os.ModeAppend)
	ioutil.WriteFile(cfgFile, []byte(config), os.ModeAppend)
}

func ReadFromFile() (template string, config string, err error) {
	tplFile := "./template/cloud-config.template"
	cfgFile := "./template/unisound-ailab/build_config.yml"
	temp, err := ioutil.ReadFile(tplFile)
	if err != nil {
		log.Printf("%v\n", err)
		return "", "", err
	}
	conf, err := ioutil.ReadFile(cfgFile)
	if err != nil {
		log.Printf("%v\n", err)
		return "", "", err
	}
	return string(temp), string(conf), nil
}

func httpGet(url string, timeout time.Duration) (string, error) {
	client := http.Client{
		Timeout: timeout,
	}
	resp, err := client.Get(url)
	if err != nil || resp.StatusCode != 200 {
		log.Printf("%v\n", err)
		return "", err
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Printf("%v\n", err)
		return "", err
	}
	return string(body), nil
}

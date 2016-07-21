package main

import (
	"os"
	"fmt"
	"log"
	"net/http"
	"io/ioutil"
	"strings"
	"time"
	"github.com/gorilla/mux"
	"golang.org/x/net/context"
	"github.com/coreos/etcd/client"
	"text/template"
	"gopkg.in/yaml.v2"
	tp "cloud-config-server/template"
)

var etcd_template_key = "/unisound/template_server/template"
var etcd_config_key = "/unisound/template_server/config"
var template_url = "https://raw.githubusercontent.com/k8sp/auto-install/cloud-config-server/cloud-config-server/template/cloud-config.template?token=ABVweRElt8m6CShy2jcwuOxlBtlXOmPKks5XmbRZwA%3D%3D"
var config_url   = "https://raw.githubusercontent.com/k8sp/auto-install/cloud-config-server/cloud-config-server/template/unisound-ailab/build_config.yml?token=ABVweT25Wg2ENyDdA3m6ukDjO4slIuz2ks5XmbSuwA%3D%3D"

var kapi client.KeysAPI

func init() {
	cfg := client.Config{
		Endpoints: []string{"http://10.10.10.192:2379"},
		Transport: client.DefaultTransport,
		// set timeout per request to fail fast when the target endpoint is unavailable
		HeaderTimeoutPerRequest: time.Second * 2,
	}
	c, err := client.New(cfg)
	if err != nil {
		log.Printf("%v\n",err)
	}
	kapi = client.NewKeysAPI(c)

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
//			w.Write([]byte("SERVER ERROR!\n"))
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
	cfg := &tp.Config{}
	err = yaml.Unmarshal([]byte(config), &cfg)
	tp.Execute(tpl, cfg, mac, w)
}

func RetriveFromGithub(timeout time.Duration) (template string, config string, err error){
	template, err = httpGet(template_url, timeout)
	if err != nil {
		log.Printf("%v\n",err)
		return "", "", err
	}
	config, err = httpGet(config_url, timeout)
	if err != nil {
		log.Printf("%v\n",err)
		return "", "", err
	}
	return template, config, nil
}

func WriteToFile(template string, config string){
        if template == "" || config == "" {
                return
        }
	tplFile := "./template/cloud-config.template"
	cfgFile := "./template/unisound-ailab/build_config.yml"
	ioutil.WriteFile(tplFile, []byte(template), os.ModeAppend)
	ioutil.WriteFile(cfgFile, []byte(config), os.ModeAppend)
}

func ReadFromFile() (template string, config string, err error){
	tplFile := "./template/cloud-config.template"
        cfgFile := "./template/unisound-ailab/build_config.yml"
	temp, err := ioutil.ReadFile(tplFile)
	if err != nil {
                log.Printf("%v\n",err)
                return "", "", err
        }
	conf, err := ioutil.ReadFile(cfgFile)
	if err != nil {
                log.Printf("%v\n",err)
                return "", "", err
        }
	return string(temp), string(conf), nil
}

func RetrieveFromEtcd() (template string, config string, err error){
	resp, err := kapi.Get(context.Background(), etcd_template_key, nil)
	if err != nil {
		log.Printf("%v\n",err)
		return "", "", err
	} else {
		template = resp.Node.Value
	}
	resp, err = kapi.Get(context.Background(), etcd_config_key, nil)
	if err != nil {
		log.Printf("%v\n",err)
		return "", "", err
	} else {
		config = resp.Node.Value
	}
	return template, config, nil
}

func CacheToEtcd(template string, config string){
	if template == "" || config == "" {
		return
	}
	fmt.Printf("%#v\n", etcd_template_key)
	resp, err := kapi.Set(context.Background(), etcd_template_key, template, nil)
	if err != nil {
		log.Printf("%v\n",err)
	} else {
		// print common key info
		log.Printf("Set is done. Metadata is %q\n", resp)
	}
	fmt.Printf("%#v\n", etcd_config_key)
	resp, err = kapi.Set(context.Background(), etcd_config_key, config, nil)
	if err != nil {
		log.Printf("%v\n",err)
	} else {
		// print common key info
		log.Printf("Set is done. Metadata is %q\n", resp)
	}
}

func httpGet(url string, timeout time.Duration) (string, error) {
	client := http.Client{
		Timeout: timeout,
	}
	resp, err := client.Get(url)
	if err != nil || resp.StatusCode != 200 {
		log.Printf("%v\n",err)
		return "", err
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		log.Printf("%v\n",err)
		return "", err
	}
	return string(body), nil
}


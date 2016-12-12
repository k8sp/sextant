package certgen

import (
	"html/template"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path"

	"github.com/topicai/candy"
)

const (
	masterOpenSSLConfTmpl = `[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
DNS.5 = {{ .HostName }}
{{ range $index, $element := .KubeMasterDNS }}
DNS.{{ add $index 6 }} = {{ $element }}
{{ end }}
{{ range $index, $element := .KubeMasterIP }}
IP.{{ add $index 1}} = {{ $element }}
{{ end }}
`

	workerOpenSSLConfTmpl = `[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = {{ .HostName }}
`
)

var funcMap = template.FuncMap{
	"add": add,
}

func add(a, b int) int {
	return (a + b)
}

// Execution struct config opendssl.conf
type Execution struct {
	HostName      string
	KubeMasterIP  []string
	KubeMasterDNS []string
}

// GenerateRootCA generate ca.key and ca.crt depending on out path
func GenerateRootCA(out string) (string, string) {
	caKey := path.Join(out, "ca.key")
	caCrt := path.Join(out, "ca.crt")
	Run("openssl", "genrsa", "-out", caKey, "2048")
	Run("openssl", "req", "-x509", "-new", "-nodes", "-key", caKey, "-days", "10000", "-out", caCrt, "-subj", "/CN=kube-ca")

	return caKey, caCrt
}

func openSSLCnfTmpl(master bool) *template.Template {
	if master == true {
		return template.Must(template.New("").Funcs(funcMap).Parse(masterOpenSSLConfTmpl))
	}
	return template.Must(template.New("").Funcs(funcMap).Parse(workerOpenSSLConfTmpl))
}

// Gen generates and returns the TLS certse.  It panics for errors.
func Gen(master bool, hostname, caKey, caCrt string, kubeMasterIP, kubeMasterDNS []string) ([]byte, []byte) {
	out, e := ioutil.TempDir("", "")
	candy.Must(e)
	defer func() {
		if e = os.RemoveAll(out); e != nil {
			log.Printf("Generator.Gen failed deleting %s", out)
		}
	}()

	cnf := path.Join(out, "openssl.cnf")
	key := path.Join(out, "key.pem")
	csr := path.Join(out, "csr.pem")
	crt := path.Join(out, "crt.pem")

	ec := Execution{
		HostName:      hostname,
		KubeMasterIP:  kubeMasterIP,
		KubeMasterDNS: kubeMasterDNS,
	}

	candy.WithCreated(cnf, func(w io.Writer) {
		candy.Must(openSSLCnfTmpl(master).Execute(w, ec))
	})
	subj := "/CN=" + hostname
	if master == true {
		subj = "/CN=kube-apiserver"
	}
	d, _ := ioutil.ReadFile(cnf)
	log.Print(string(d))
	Run("openssl", "genrsa", "-out", key, "2048")
	Run("openssl", "req", "-new", "-key", key, "-out", csr, "-subj", subj, "-config", cnf)
	Run("openssl", "x509", "-req", "-in", csr, "-CA", caCrt, "-CAkey", caKey, "-CAcreateserial", "-out", crt, "-days", "365", "-extensions", "v3_req", "-extfile", cnf)

	k, e := ioutil.ReadFile(key)
	candy.Must(e)
	c, e := ioutil.ReadFile(crt)
	candy.Must(e)
	return k, c
}

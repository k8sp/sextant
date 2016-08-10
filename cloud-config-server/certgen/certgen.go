package certgen

import (
	"html/template"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path"
	"strings"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
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
IP.1 = 10.100.0.1
IP.2 = {{.}}
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
IP.1 = {{.}}
`
)

func openSSLCnfTmpl(role string) *template.Template {
	if role == "master" {
		return template.Must(template.New("").Parse(masterOpenSSLConfTmpl))
	}
	return template.Must(template.New("").Parse(workerOpenSSLConfTmpl))
}

// Gen generates and returns the TLS certse.  It panics for errors.
func Gen(ip, role, caCrt, caKey string) ([]byte, []byte) {
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

	candy.WithCreated(cnf, func(w io.Writer) {
		candy.Must(openSSLCnfTmpl(role).Execute(w, ip))
	})
	d, _ := ioutil.ReadFile(cnf)
	log.Print(string(d))
	subj := "/CN=worker-" + strings.Replace(ip, ".", "-", -1)
	if role == "master" {
		subj = "/CN=kube-apiserver"
	}

	cmd.Run("openssl", "genrsa", "-out", key, "2048")
	cmd.Run("openssl", "req", "-new", "-key", key, "-out", csr, "-subj", subj, "-config", cnf)
	cmd.Run("openssl", "x509", "-req", "-in", csr, "-CA", caCrt, "-CAkey", caKey, "-CAcreateserial", "-out", crt, "-days", "365", "-extensions", "v3_req", "-extfile", cnf)

	k, e := ioutil.ReadFile(key)
	candy.Must(e)
	c, e := ioutil.ReadFile(crt)
	candy.Must(e)
	return k, c
}

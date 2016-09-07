package certgen

import (
	"html/template"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path"

	"github.com/k8sp/sextant/bootstrapper/cmd"
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
DNS.5 = {{.}}
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
DNS.1 = {{.}}
`
)

// GenerateRootCA generate ca.key and ca.crt depending on out path
func GenerateRootCA(out string) (string, string) {
	caKey := path.Join(out, "ca.key")
	caCrt := path.Join(out, "ca.crt")
	cmd.Run("openssl", "genrsa", "-out", caKey, "2048")
	cmd.Run("openssl", "req", "-x509", "-new", "-nodes", "-key", caKey, "-days", "10000", "-out", caCrt, "-subj", "/CN=kube-ca")

	return caKey, caCrt
}

func openSSLCnfTmpl(master bool) *template.Template {
	if master == true {
		return template.Must(template.New("").Parse(masterOpenSSLConfTmpl))
	}
	return template.Must(template.New("").Parse(workerOpenSSLConfTmpl))
}

// Gen generates and returns the TLS certse.  It panics for errors.
func Gen(master bool, hostname, caKey, caCrt string) ([]byte, []byte) {
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
		candy.Must(openSSLCnfTmpl(master).Execute(w, hostname))
	})
	subj := "/CN=" + hostname
	if master == true {
		subj = "/CN=kube-apiserver"
	}
	d, _ := ioutil.ReadFile(cnf)
	log.Print(string(d))
	cmd.Run("openssl", "genrsa", "-out", key, "2048")
	cmd.Run("openssl", "req", "-new", "-key", key, "-out", csr, "-subj", subj, "-config", cnf)
	cmd.Run("openssl", "x509", "-req", "-in", csr, "-CA", caCrt, "-CAkey", caKey, "-CAcreateserial", "-out", crt, "-days", "365", "-extensions", "v3_req", "-extfile", cnf)

	k, e := ioutil.ReadFile(key)
	candy.Must(e)
	c, e := ioutil.ReadFile(crt)
	candy.Must(e)
	return k, c
}

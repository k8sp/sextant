package tls

import (
	"bytes"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path"
	"strings"

	"github.com/topicai/candy"
)

// Generate tls cert files, the folder struct:
// TlsBaseDir
//	`-data
//		`-master-{ip}
//			`-apiserver-key.pem
//			|-apiserver.pem
//			|-openssl.cnf
//		|-worker-{ip}
//			`-worker.pem
//			|-worker-key.pem
//			|-worker-openssl.cnf
// 	|-etc
//		`-openssl.cnf
//		|-worker-openssl.cnf

// TLS is a
type TLS struct {
	caCrt            string
	caKey            string
	tlsCertDir       string
	tlsTplDir        string
	tplMasterOpenssl string
	tplWorkerOpenssl string
}

// New construct a TLS type
func New(caCrt, caKey, tlsCertDir, tlsTplDir string) *TLS {
	t := &TLS{
		caCrt:            caCrt,
		caKey:            caKey,
		tlsCertDir:       tlsCertDir,
		tlsTplDir:        tlsTplDir,
		tplMasterOpenssl: path.Join(tlsTplDir, "openssl.cnf"),
		tplWorkerOpenssl: path.Join(tlsTplDir, "worker-openssl.cnf"),
	}
	return t
}

func fileExist(filename string) bool {
	_, err := os.Stat(filename)
	return err == nil
}

// GenerateCert depending on role and ip
func (t *TLS) GenerateCert(role, ip string) ([]byte, error) {
	if role == "master" {
		return t.GenerateMasterCert(ip)
	}
	return t.GenerateWorkerCert(ip)
}

// GenerateWorkerCert generate master cert files, located ./tls/data/master-${ip}/
func (t *TLS) GenerateWorkerCert(ip string) ([]byte, error) {
	var dataDir = path.Join(t.tlsCertDir, "worker-"+ip)
	var workerConfPath = dataDir + "/worker-openssl.cnf"
	var workerPem = dataDir + "/worker.pem"
	var workerKeyPem = dataDir + "/worker-key.pem"
	var workerCSRPath = dataDir + "/worker.csr"
	os.Mkdir(dataDir, os.ModePerm)

	cmd := exec.Command("bash", "-s")
	cmdString := `
sed "s/<WORKER_HOST>/` + ip + `/g" ` + t.tplWorkerOpenssl + ` > ` + workerConfPath + `
openssl genrsa -out ` + workerKeyPem + ` 2048
openssl req -new -key ` + workerKeyPem + ` -out ` + workerCSRPath + ` -subj "/CN=worker" -config ` + workerConfPath + `
openssl x509 -req -in ` + workerCSRPath + ` -CA ` + t.caCrt + ` -CAkey ` + t.caKey +
		` -CAcreateserial -out ` + workerPem + ` -days 365 -extensions v3_req -extfile ` + workerConfPath
	cmd.Stdin = strings.NewReader(cmdString)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if e := cmd.Run(); e != nil {
		log.Printf("Generate worker cert fail: %s\n", stderr.String())
		return []byte(""), e
	}

	dataWorker, e := ioutil.ReadFile(workerPem)
	candy.Must(e)
	dataWorkerKey, e := ioutil.ReadFile(workerKeyPem)
	candy.Must(e)
	dataCA, e := ioutil.ReadFile(t.caCrt)
	candy.Must(e)

	data := bytes.Buffer{}
	data.Write(dataWorker)
	data.WriteString("<>\n")
	data.Write(dataWorkerKey)
	data.WriteString("<>\n")
	data.Write(dataCA)
	return data.Bytes(), nil
}

// GenerateMasterCert generate worker cert files, located ./tls/data/worker-${ip}/
func (t *TLS) GenerateMasterCert(ip string) ([]byte, error) {
	var dataDir = path.Join(t.tlsCertDir, "master-"+ip)
	var masterConfPath = dataDir + "/openssl.cnf"
	var apiserverCsr = dataDir + "/apiserver.csr"
	var apiserverPem = dataDir + "/apiserver.pem"
	var apiserverKeyPem = dataDir + "/apiserver-key.pem"
	os.Mkdir(dataDir, os.ModePerm)

	cmd := exec.Command("bash", "-s")
	cmdString := `
sed "s/<MASTER_HOST>/` + ip + `/g" ` + t.tplMasterOpenssl + ` > ` + masterConfPath + `
openssl genrsa -out ` + apiserverKeyPem + ` 2048 \n
openssl req -new -key ` + apiserverKeyPem + ` -out ` + apiserverCsr + ` -subj "/CN=kube-apiserver" -config ` + masterConfPath + `
openssl x509 -req -in ` + apiserverCsr + ` -CA ` + t.caCrt + ` -CAkey ` + t.caKey + ` -CAcreateserial -out \
` + apiserverPem + ` -days 365 -extensions v3_req -extfile ` + masterConfPath
	cmd.Stdin = strings.NewReader(cmdString)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if e := cmd.Run(); e != nil {
		log.Printf("Generate master cert fail: %s\n", stderr.String())
		return []byte(""), e
	}

	dataAPIServer, e := ioutil.ReadFile(apiserverPem)
	candy.Must(e)
	dataAPIServerKey, e := ioutil.ReadFile(apiserverKeyPem)
	candy.Must(e)
	dataCA, e := ioutil.ReadFile(t.caCrt)
	candy.Must(e)

	data := bytes.Buffer{}
	data.Write(dataAPIServer)
	data.WriteString("<>\n")
	data.Write(dataAPIServerKey)
	data.WriteString("<>\n")
	data.Write(dataCA)
	return data.Bytes(), nil
}

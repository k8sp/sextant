package tls

import (
	"bytes"
	"errors"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"strings"

	"github.com/topicai/candy"
)

// TLS is a struct containe TLS root cert
type TLS struct {
	// CAPem is Root CA Cert
	CAPem string

	// CAKeyPem is Root CA Key Cert
	CAKeyPem string
}

// CertBaseDIR The base fold of saving cert files
var CertBaseDIR = os.Getenv("GOPATH") + "/src/github.com/k8sp/auto-install/cloud-config-server/TLS"

// CertDataBaseDIR is data fold
var CertDataBaseDIR = CertBaseDIR + "/data"

// CertEtcDIR file
var CertEtcDIR = CertBaseDIR + "/etc"

func fileExist(filename string) bool {
	_, err := os.Stat(filename)
	return err == nil
}

// GenerateCerts genearete cert file dependence role and ip
func (t TLS) GenerateCerts(role string, ip string) (data string, err error) {
	if role == "master" {
		return t.GenerateMasterCert(ip), nil
	} else if role == "worker" {
		return t.GenerateWorkerCert(ip), nil
	}
	return "", errors.New("Role should be master or worker")
}

// GenerateWorkerCert generate master cert files, located ./TLS/data/master-${ip}/
func (t TLS) GenerateWorkerCert(ip string) string {
	var dataDir = CertDataBaseDIR + "/worker-" + ip
	var workerConfPath = dataDir + "/worker-openssl.cnf"
	var workerPem = dataDir + "/worker.pem"
	var workerKeyPem = dataDir + "/worker-key.pem"
	var workerCSRPath = dataDir + "/worker.csr"
	os.Mkdir(dataDir, os.ModePerm)

	cmd := exec.Command("bash", "-s")
	cmdString := `
	  sed "s/<WORKER_HOST>/` + ip + `/g" ` + CertEtcDIR + `/worker-openssl.cnf > ` + workerConfPath + `
		openssl genrsa -out ` + workerKeyPem + ` 2048
		openssl req -new -key ` + workerKeyPem + ` -out ` + workerCSRPath + ` -subj "/CN=worker" -config ` + workerConfPath + `
		openssl x509 -req -in ` + workerCSRPath + ` -CA ` + t.CAPem + ` -CAkey ` + t.CAKeyPem +
		` -CAcreateserial -out ` + workerPem + ` -days 365 -extensions v3_req -extfile ` + workerConfPath
	cmd.Stdin = strings.NewReader(cmdString)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		log.Printf("Generate worker cert fail: %v\n", err)
		return ""
	}

	dataWorker, e := ioutil.ReadFile(workerPem)
	candy.Must(e)
	dataWorkerKey, e := ioutil.ReadFile(workerKeyPem)
	candy.Must(e)
	dataCA, e := ioutil.ReadFile(t.CAPem)
	candy.Must(e)

	data := bytes.Buffer{}
	data.Write(dataWorker)
	data.WriteString("<>\n")
	data.Write(dataWorkerKey)
	data.WriteString("<>\n")
	data.Write(dataCA)
	return data.String()
}

// GenerateMasterCert generate worker cert files, located ./TLS/data/worker-${ip}/
func (t TLS) GenerateMasterCert(ip string) string {
	var dataDir = CertDataBaseDIR + "/master-" + ip
	var masterConfPath = dataDir + "/openssl.cnf"
	var apiserverCsr = dataDir + "/apiserver.csr"
	var apiserverPem = dataDir + "/apiserver.pem"
	var apiserverKeyPem = dataDir + "/apiserver-key.pem"
	log.Printf("Generate master %s cert...", ip)
	os.Mkdir(dataDir, os.ModePerm)

	cmd := exec.Command("bash", "-s")
	cmdString := `
sed "s/<MASTER_HOST>/` + ip + `/g" ` + CertEtcDIR + `/openssl.cnf > ` + masterConfPath + `
openssl genrsa -out ` + apiserverKeyPem + ` 2048 \n
openssl req -new -key ` + apiserverKeyPem + ` -out ` + apiserverCsr + ` -subj "/CN=kube-apiserver" -config ` + masterConfPath + `
openssl x509 -req -in ` + apiserverCsr + ` -CA ` + t.CAPem + ` -CAkey ` + t.CAKeyPem + ` -CAcreateserial -out \
` + apiserverPem + ` -days 365 -extensions v3_req -extfile ` + masterConfPath
	cmd.Stdin = strings.NewReader(cmdString)
	var out bytes.Buffer
	var stderr bytes.Buffer
	cmd.Stdout = &out
	cmd.Stderr = &stderr
	err := cmd.Run()
	if err != nil {
		log.Printf("Generate master cert fail: %v\n", stderr)
		return ""
	}

	dataAPIServer, e := ioutil.ReadFile(apiserverPem)
	candy.Must(e)
	dataAPIServerKey, e := ioutil.ReadFile(apiserverKeyPem)
	candy.Must(e)
	dataCA, e := ioutil.ReadFile(t.CAPem)
	candy.Must(e)

	data := bytes.Buffer{}
	data.Write(dataAPIServer)
	data.WriteString("<>\n")
	data.Write(dataAPIServerKey)
	data.WriteString("<>\n")
	data.Write(dataCA)
	return data.String()
}

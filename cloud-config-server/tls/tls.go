package tls

import (
	"bytes"
	"errors"
	"log"
	"os"
	"os/exec"
	"strings"
)

type Tls struct {
	// CAPem is Root CA Cert
	CAPem string

	// CAKeyPem is Root CA Key Cert
	CAKeyPem string
}

// CertBaseDIR The base fold of saving cert files
var CertBaseDIR = os.Getenv("GOPATH") + "/src/github.com/k8sp/auto-install/cloud-config-server/tls"

// CertDataBaseDIR is data fold
var CertDataBaseDIR = CertBaseDIR + "/data"

// CertEtcDIR file
var CertEtcDIR = CertBaseDIR + "/etc"

func fileExist(filename string) bool {
	_, err := os.Stat(filename)
	return err == nil
}

func (t Tls) GenerateCerts(role string, ip string) (string, error) {
	if role == "master" {
        log.Printf(role + ip)
		return t.GenerateMasterCert(ip), nil
	} else if role == "worker" {
		return t.GenerateWorkerCert(ip), nil
	}
	return "", errors.New("Role should be master or worker")
}

// GenerateWorkerCert generate master cert files, located ./tls/data/master-${ip}/
func (t Tls) GenerateWorkerCert(ip string) string {
	var dataDir = CertDataBaseDIR + "/worker-" + ip
	var workerConfPath = dataDir + "/worker-openssl.cnf"
	var workerPath = dataDir + "/worker.pem"
	var workerKeyPath = dataDir + "/worker-key.pem"
	var workerCSRPath = dataDir + "/worker.csr"
	os.Mkdir(dataDir, os.ModePerm)

	cmd := exec.Command("bash", "-s")
	cmdString := `
	  sed "s/<WORKER_HOST>/` + ip + `/g" ` + CertEtcDIR + `/worker-openssl.cnf > ` + workerConfPath + `
		openssl genrsa -out ` + workerKeyPath + ` 2048
		openssl req -new -key ` + workerKeyPath + ` -out ` + workerCSRPath + ` -subj "/CN=worker" -config ` + workerConfPath + `
		openssl x509 -req -in ` + workerCSRPath + ` -CA ` + t.CAPem + ` -CAkey ` + t.CAKeyPem +
		` -CAcreateserial -out ` + workerPath + ` -days 365 -extensions v3_req -extfile ` + workerConfPath
	cmd.Stdin = strings.NewReader(cmdString)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		log.Printf("%v\n", err)
		return ""
	}
	return ""
}

// GenerateMasterCert generate worker cert files, located ./tls/data/worker-${ip}/
func (t Tls) GenerateMasterCert(ip string) string {
	var dataDir = CertDataBaseDIR + "/master-" + ip
	var masterConfPath = dataDir + "/openssl.cnf"
	var apiserverCsr = dataDir + "/apiserver.csr"
	var apiserverPem = dataDir + "/apiserver.pem"
	var apiserverKeyPem = dataDir + "/apiserver-key.pem"
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
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		log.Printf("%v\n", err)
		return ""
	}
	return ""
}

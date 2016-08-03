package tls

import (
	"bytes"
	"log"
	"os"
	"os/exec"
	"strings"
)

// CertBaseDIR The base fold of saving cert files
var CertBaseDIR = os.Getenv("GOPATH") + "/src/github.com/k8sp/auto-install/cloud-config-server/tls"

// CertDataBaseDIR is data fold
var CertDataBaseDIR = CertBaseDIR + "/data"

// CAPem file
var CAPem = CertBaseDIR + "/data/ca.pem"

// CAKeyPem file
var CAKeyPem = CertBaseDIR + "/data/ca-key.pem"

// CertEtcDIR file
var CertEtcDIR = CertBaseDIR + "/etc"

func fileExist(filename string) bool {
	_, err := os.Stat(filename)
	return err == nil
}

// InitRootCert generate root cert files, located ./tls/data
func InitRootCert() bool {
	if fileExist(CAPem) || fileExist(CAKeyPem) {
		log.Printf("Root CA file has already exists.")
		return false
	}

	cmd := exec.Command("bash", "-s")
	cmdString := `
		openssl genrsa -out ` + CAKeyPem + ` 2048
		openssl req -x509 -new -nodes -key ` + CAKeyPem + ` -days 10000 -out ` + CAPem + ` -subj "/CN=kube-ca"`
	cmd.Stdin = strings.NewReader(cmdString)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		log.Printf("%v\n", err)
		return false
	}
	return true
}

// GenerateWorkerCert generate master cert files, located ./tls/data/master-${ip}/
func GenerateWorkerCert(ip string) bool {
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
		openssl x509 -req -in ` + workerCSRPath + ` -CA ` + CAPem + ` -CAkey ` + CAKeyPem +
		` -CAcreateserial -out ` + workerPath + ` -days 365 -extensions v3_req -extfile ` + workerConfPath
	cmd.Stdin = strings.NewReader(cmdString)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		log.Printf("%v\n", err)
		return false
	}
	return true
}

// GenerateMasterCert generate worker cert files, located ./tls/data/worker-${ip}/
func GenerateMasterCert(ip string) bool {
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
		openssl x509 -req -in ` + apiserverCsr + ` -CA ` + CAPem + ` -CAkey ` + CAKeyPem + ` -CAcreateserial -out \
			` + apiserverPem + ` -days 365 -extensions v3_req -extfile ` + masterConfPath
	cmd.Stdin = strings.NewReader(cmdString)
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		log.Printf("%v\n", err)
		return false
	}
	return true
}

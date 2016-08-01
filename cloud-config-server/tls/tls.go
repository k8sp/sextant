package tls

import (
	"log"
	"os"
	"os/exec"
)

// CertBaseDIR The base fold of saving cert files
var CertBaseDIR = os.Getenv("GOPATH") + "/src/github.com/k8sp/auto-install/cloud-config-server/tls"

func fileExist(filename string) bool {
	_, err := os.Stat(filename)
	return err == nil
}

// InitRootCert generate root cert files, located ./tls/data
func InitRootCert() bool {
	if fileExist(CertBaseDIR+"/data/ca.pem") || fileExist(CertBaseDIR+"/data/ca-key.pem") {
		log.Printf("Root CA file has already exists.")
		return false
	}
	out, err := exec.Command("/bin/bash", CertBaseDIR+"/bin/generate_cert.sh",
		CertBaseDIR, "root").Output()
	if err != nil {
		log.Printf("Generate root ac files failed: %s", out)
		return false
	}
	return true
}

// GenerateMasterCert generate master cert files, located ./tls/data/master-${ip}/
func GenerateMasterCert(ip string) bool {
	out, err := exec.Command("/bin/bash", CertBaseDIR+"/bin/generate_cert.sh",
		CertBaseDIR, "master", ip).Output()
	if err != nil {
		log.Printf("Gernate master node cert file failed: %s", out)
		return false
	}
	return true
}

// GenerateWorkerCert generate worker cert files, located ./tls/data/worker-${ip}/
func GenerateWorkerCert(ip string) bool {
	out, err := exec.Command("/bin/bash", CertBaseDIR+"/bin/generate_cert.sh",
		CertBaseDIR, "worker", ip).Output()
	if err != nil {
		log.Printf("Gernate worker node cert file failed: %s", out)
		return false
	}
	return true
}

package tls

import (
	"testing"
)

func TestGenerateMasterCert(t *testing.T) {
	InitRootCert()
	GenerateMasterCert("192.168.2.3")
	if fileExist(CertBaseDIR+"/data/master-192.168.2.3/apiserver.pem") &&
		fileExist(CertBaseDIR+"/data/master-192.168.2.3/apiserver-key.pem") &&
		fileExist(CertBaseDIR+"/data/master-192.168.2.3/openssl.cnf") {
		t.Log("apiserver.pem, apiserver-key.pem, openssl.cnf successing generated.")
	} else {
		t.Error("apiserver.pem, apiserver-key.pem, openssl.cnf generate failed.")
	}
}
func TestGenerateRootCert(t *testing.T) {
	InitRootCert()
	if fileExist(CertBaseDIR+"/data/ca.pem") &&
		fileExist(CertBaseDIR+"/data/ca-key.pem") {
		t.Log("ca.pem, ca-key.pem successing generated.")
	} else {
		t.Error("ca.pem, ca-key.pem successing generate failed.")
	}
}

func TestGenerateWorkerCert(t *testing.T) {
	InitRootCert()
	GenerateWorkerCert("192.168.2.3")
	if fileExist(CertBaseDIR+"/data/worker-192.168.2.3/worker.pem") &&
		fileExist(CertBaseDIR+"/data/worker-192.168.2.3/worker-key.pem") {
		t.Log("worker.pem, worker-key.pem, worker-openssl.cnf successing generated.")
	} else {
		t.Error("worker.pem, worker-key.pem, worker-openssl.cnf generate failed.")
	}
}

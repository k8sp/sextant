package tls

import (
	"io/ioutil"
	"path"
	"testing"

	"github.com/topicai/candy"
)

const (
	caCrt      = "src/github.com/k8sp/auto-install/cloud-config-server/tls/testdata/ca.pem"
	caKey      = "src/github.com/k8sp/auto-install/cloud-config-server/tls/testdata/ca-key.pem"
	tlsCertDir = "src/github.com/k8sp/auto-install/cloud-config-server/tls/data"
	tlsTplDir  = "src/github.com/k8sp/auto-install/cloud-config-server/tls/etc"
)

func TestGenerateMasterCert(t *testing.T) {
	tmpDir, e := ioutil.TempDir("", "")
	candy.Must(e)
	t.Log("Tmp path: " + tmpDir)
	tls := New(path.Join(candy.GoPath(), caCrt), path.Join(candy.GoPath(), caKey),
		tmpDir, path.Join(candy.GoPath(), tlsTplDir))

	_, err := tls.GenerateMasterCert("192.168.2.3")
	if err != nil {
		t.Error("apiserver.pem, apiserver-key.pem, openssl.cnf generate failed: " + err.Error())
	}
	if fileExist(path.Join(tmpDir, "master-192.168.2.3/apiserver.pem")) &&
		fileExist(path.Join(tmpDir, "master-192.168.2.3/apiserver-key.pem")) {
		t.Log("apiserver.pem, apiserver-key.pem, openssl.cnf successing generated.")
	} else {
		t.Error("apiserver.pem, apiserver-key.pem, openssl.cnf generate failed.")
	}
}
func TestGenerateWorkerCert(t *testing.T) {

	tmpDir, e := ioutil.TempDir("", "")
	candy.Must(e)
	t.Log("Tmp path: " + tmpDir)
	tls := New(path.Join(candy.GoPath(), caCrt), path.Join(candy.GoPath(), caKey),
		tmpDir, path.Join(candy.GoPath(), tlsTplDir))

	_, err := tls.GenerateWorkerCert("192.168.2.3")
	if err != nil {
		t.Error("apiserver.pem, apiserver-key.pem, openssl.cnf generate failed: " + err.Error())
	}
	if fileExist(path.Join(tmpDir, "worker-192.168.2.3/worker.pem")) &&
		fileExist(path.Join(tmpDir, "worker-192.168.2.3/worker-key.pem")) {
		t.Log("worker.pem, worker-key.pem, worker-openssl.cnf successing generated.")
	} else {
		t.Error("worker.pem, worker-key.pem, worker-openssl.cnf generate failed.")
	}
}

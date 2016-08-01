package config

import (
	"io/ioutil"
	"log"

	tptls "github.com/k8sp/auto-install/cloud-config-server/tls"
)

func readCertFile(file string) string {
	data, err := ioutil.ReadFile(file)
	if err != nil {
		log.Printf("%s\n", err)
		return ""
	}
	return string(data)

}

// CertCA return ca.pem
func (c Cluster) CertCA() string {
	certFile := tptls.CertBaseDIR + "/data/ca.pem"
	return readCertFile(certFile)
}

// CertAPIServer return apiserver.pem
func (c Cluster) CertAPIServer(ip string) string {
	certFile := tptls.CertBaseDIR + "/data/master-" + ip + "/apiserver.pem"
	return readCertFile(certFile)
}

// CertAPIServerKey return apiserver-key.pem
func (c Cluster) CertAPIServerKey(ip string) string {
	certFile := tptls.CertBaseDIR + "/data/master-" + ip + "/apiserver-key.pem"
	return readCertFile(certFile)
}

// CertWorker return worker.pem
func (c Cluster) CertWorker(ip string) string {
	certFile := tptls.CertBaseDIR + "/data/worker-" + ip + "/worker.pem"
	return readCertFile(certFile)
}

// CertWorkerKey return worker-key.pem
func (c Cluster) CertWorkerKey(ip string) string {
	certFile := tptls.CertBaseDIR + "/data/worker-" + ip + "/worker-key.pem"
	return readCertFile(certFile)
}

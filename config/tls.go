package config

import (
	"io/ioutil"
	"log"

	tptls "github.com/k8sp/auto-install/cloud-config-server/tls"
)

func ReadCertFile(file string) string {
	data, err := ioutil.ReadFile(file)
	if err != nil {
		log.Printf("%s\n", err)
		return ""
	}
	return string(data)

}

func (c Cluster) CertCA() string {
	certFile := tptls.CertBaseDIR + "/data/ca.pem"
	return ReadCertFile(certFile)
}
func (c Cluster) CertApiServer(ip string) string {
	certFile := tptls.CertBaseDIR + "/data/master-" + ip + "/apiserver.pem"
	return ReadCertFile(certFile)
}
func (c Cluster) CertApiServerKey(ip string) string {
	certFile := tptls.CertBaseDIR + "/data/master-" + ip + "/apiserver-key.pem"
	return ReadCertFile(certFile)
}
func (c Cluster) CertWorker(ip string) string {
	certFile := tptls.CertBaseDIR + "/data/worker-" + ip + "/worker.pem"
	return ReadCertFile(certFile)
}
func (c Cluster) CertWorkerKey(ip string) string {
	certFile := tptls.CertBaseDIR + "/data/worker-" + ip + "/worker-key.pem"
	return ReadCertFile(certFile)
}

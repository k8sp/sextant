package skydns

import (
	"bytes"
	"fmt"
	"html/template"
	"io"
	"log"
	"runtime"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
)

// skydnsService executes a template with a Cluster variable to generate
// /etc/systemd/system/skydns.service
func MakeService(tf string, c *config.Cluster) string {
	tmpl := template.New("")

	if len(tf) > 0 {
		tmpl = template.Must(tmpl.Parse(tf))
	} else {
		tmpl = template.Must(tmpl.Parse(tmplServiceContent))
	}

	var buf bytes.Buffer
	candy.Must(tmpl.Execute(&buf, c))
	return buf.String()
}

const (
	tmplServiceContent = `
[Unit]
Description=SkyDNS
After=network.target
Requires=network.target

[Service]
Type=simple
ExecStart=/usr/bin/skydns -machines=http://10.10.10.201:2379 -addr=0.0.0.0:53 -nameservers=8.8.8.8:53,8.8.4.4:53 -domain=unisound.com.

[Install]
WantedBy=multi-user.target
`
)

// Build checks out and build SkyDNS.
func Download(outDir string) {
	InstallGo()

	// TODO(y): Set environment variable.
	cmd.Run("go", "get")
}

// Requires curl.
func InstallGo(version string) {
	if runtime.GOOS != "linux" || runtime.GOARCH != "amd64" {
		log.Panicf("InstallGo must work with linux/amd64, but not %s/%s", runtime.GOOS, runtime.GOARCH)
	}

	if len(version) == 0 {
		version = "1.6.3"
	}
	cmd.Run("curl", "-s", "-o", "/tmp/go.tar.gz",
		fmt.Sprintf("https://storage.googleapis.com/golang/go%s.linux-amd64.tar.gz", version))

	cmd.Run("tar", "-C", "/usr/local", "-xzf", "/tmp/go.tar.gz")
	cmd.Run("ln", "-s", "/usr/local/go/bin/go", "/usr/local/bin/go")
}

// Install and configure SkyDNS service on CentOS
func InstallonCentOS(tmpl string, c *config.Cluster) {

	DownloadSkyDNSBinary("/usr/bin")

	//create /etc/systemd/system/skydns.service
	candy.WithCreated("/etc/systemd/system/skydns.service", func(w io.Writer) {
		_, e := fmt.Fprint(w, MakeService(tmpl, c))
		candy.Must(e)
	})

	cmd.Run("systemctl", "enable", "skydns")
	// Due to a bug of CentOS, systemctl cannot run in
	// Docker containers.  Discussions and the explanation
	// of this bug is at
	// https://github.com/docker/docker/issues/7459.  The
	// current fix
	// https://github.com/docker-library/docs/tree/master/centos#systemd-integration
	// is too complex that I don't want to implement.  So
	// I call Try here.
	cmd.Try("systemctl", "restart", "skydns")
}

// Install and configure SkyDNS service on Ubuntu
func InstallonUbuntu(tmpl string, c *config.Cluster) {

	DownloadSkyDNSBinary("/usr/bin")

}

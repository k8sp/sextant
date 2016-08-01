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

func serviceUnit(tmpl string, c *config.Cluster) string {
	t := template.New("")

	if len(tmpl) > 0 {
		t = template.Must(t.Parse(tmpl))
	} else {
		t = template.Must(t.Parse(defaultTemplate))
	}

	var buf bytes.Buffer
	candy.Must(t.Execute(&buf, c))
	return buf.String()
}

const (
	defaultTemplate = `
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

func build() {
	installGo("")

	cmd.RunWithEnv(map[string]string{"GOPATH": "/tmp"},
		"go", "get", "-u", "github.com/skynetservices/skydns")

	cmd.Run("cp", "/tmp/bin/skydns", "/usr/bin/")
}

func installGo(version string) {
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

// Install downloads and builds SkyDNS into /usr/bin/skydns.  It then
// creates a systemd service unit for CentOS.
func Install(tmpl string, c *config.Cluster) {
	build()

	if config.LinuxDistro() == "centos" {
		candy.WithCreated("/etc/systemd/system/skydns.service", func(w io.Writer) {
			_, e := fmt.Fprint(w, serviceUnit(tmpl, c))
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
}

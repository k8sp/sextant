package skydns

import (
	"bytes"
	"fmt"
	"html/template"
	"io"
	"log"
	"path"
	"runtime"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
)

func serviceUnit(dist string, tmpl string, c *config.Cluster) string {
	t := template.New("")

	if len(tmpl) > 0 {
		t = template.Must(t.Parse(tmpl))
	} else {
		if dist == "centos" {
			t = template.Must(t.Parse(systemdDefaultTemplate))
		} else if dist == "ubuntu" {
			t = template.Must(t.Parse(upstartDefaultTemplate))
		}
	}

	var buf bytes.Buffer
	candy.Must(t.Execute(&buf, c))
	return buf.String()
}

const (
	systemdDefaultTemplate = `
[Unit]
Description=SkyDNS
After=network.target
Requires=network.target

[Service]
Type=simple
ExecStart=/usr/bin/skydns -machines={{.GetEtcdMachines}} -addr=0.0.0.0:53 -nameservers=8.8.8.8:53,8.8.4.4:53 -domain={{.DomainName}}.

[Install]
WantedBy=multi-user.target
`
	upstartDefaultTemplate = `
description "SkyDNS service"

start on runlevel [2345]
stop on runlevel [^2345]

respawn
respawn limit 20 3

script
echo $$ > /var/run/skydns.pid
exec /usr/bin/skydns -machines={{.GetEtcdMachines}} -addr=0.0.0.0:53 -nameservers=8.8.8.8:53,8.8.4.4:53 -domain={{.DomainName}}.
end script

pre-start script
end script

pre-stop script
    rm /var/run/skydns.pid
end script
`
)

func build() {
	installGo("")

	// Be careful, need antiGFW to download
	cmd.RunWithEnv(map[string]string{"GOPATH": "/tmp"},
		"/usr/local/go/bin/go", "get", "-u", "github.com/skynetservices/skydns")

	cmd.Run("/bin/cp", "-f", "/tmp/bin/skydns", "/usr/bin/")
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
}

// Download SkyDNS bianary file from github.
// requires that curl have been installed.
func getSkyDNSFile() {
	skydnsfile := path.Join("/usr/bin", "skydns")
	cmd.Run("curl", "-o", skydnsfile, "https://raw.githubusercontent.com/pineking/skydns-binary/master/skydns")
	cmd.Run("chmod", "755", skydnsfile)
}

// Install downloads and builds SkyDNS into /usr/bin/skydns.  It then
// creates a systemd service unit for CentOS.
func Install(tmpl string, c *config.Cluster) {
	build()

	switch dist := config.LinuxDistro(); dist {
	case "centos":
		candy.WithCreated("/etc/systemd/system/skydns.service", func(w io.Writer) {
			_, e := fmt.Fprint(w, serviceUnit(dist, tmpl, c))
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
	case "ubuntu":
		candy.WithCreated("/etc/init/skydns.conf", func(w io.Writer) {
			_, e := fmt.Fprint(w, serviceUnit(dist, tmpl, c))
			candy.Must(e)
		})

		cmd.Run("service", "skydns", "restart")
	default:
		log.Panicf("Unsupported OS: %s", dist)
	}
}

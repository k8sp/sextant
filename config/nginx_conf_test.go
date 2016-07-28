package config

import (
	"bytes"
	"github.com/topicai/candy"
	"html/template"
)

// NginxConf executes a template with a Cluster variable to generate
// /etc/nginx/nginx.conf.
func NginxConf(tf string, c *Cluster) string {
	tmpl := template.New("")

	if len(tf) > 0 {
		tmpl = template.Must(tmpl.Parse(tf))
	} else {
		tmpl = template.Must(tmpl.Parse(tmplNginxConf))
	}

	var buf bytes.Buffer
	candy.Must(tmpl.Execute(&buf, c))
	return buf.String()
}

const (
	tmplNginxConf = `
user  nginx;

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    access_log  /var/log/nginx/access.log;

    sendfile        on;

    server {






    }
}
`
)

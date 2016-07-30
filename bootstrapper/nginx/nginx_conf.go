package nginx

import (
	"bytes"
	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
	"html/template"
)

// NginxConf executes a template with a Cluster variable to generate
// /etc/nginx/nginx.conf.
func Conf(tf string, c *config.Cluster) string {
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
events {

}

error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    access_log  /var/log/nginx/access.log;

    sendfile        on;

    server {
        listen       80;
        server_name  localhost;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;

        location / {
            root   {{.NginxRootDir}};
            index  index.html index.htm;
        }

        location /cloud-config/ {
            proxy_pass   http://{{.Bootstrapper}}:8080;
        }

    }
}
`
)

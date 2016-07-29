package config

import (
	"github.com/stretchr/testify/assert"
	"github.com/topicai/candy"
	"gopkg.in/yaml.v2"
	"testing"
)

func TestNginxConf(t *testing.T) {
	c := &Cluster{}
	candy.Must(yaml.Unmarshal([]byte(testConfig), c))
	assert.Equal(t, nginxConf, NginxConf("", c))
}

const (
	nginxConf = `
user  nginx;

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
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }

        location /cloud-config/ {
            proxy_pass   http://10.10.10.192:8080;
        }

    }
}
`
)

package nginx

const (
	nginxConf = `
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
            root   /usr/share/nginx/html;
            index  index.html index.htm;
        }

        location /cloud-config/ {
            proxy_pass   http://172.17.0.2:8080;
        }

    }
}
`
)

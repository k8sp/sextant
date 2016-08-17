# bsroot

1. `/dnsmasq.conf`: dnsmasq config file.

1. `/registry.yml`: docker registry config file.

1. `/registry/`: directory mounted bootstrapper container as registry volume.

To build the bootstrapper Docker image:
```
sudo docker build -t registry -f registry.Dockerfile .
```

To run the bootstrapper as a Docker container named `registry`:
```
sudo docker run -d --privileged -p 5000:5000 --name registry -v $(pwd)/bsroot:/bsroot registry
```

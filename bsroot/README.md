# bsroot

The *bootstrapper* Docker image contains services including dnsmasq,
cloud-config-server, and Docker registry.  The general idea about
*bsroot* is that we put most data files and configuration files for
these services in a directory on the host, and this directory will be
mounted into the bootstrapper container as `/bsroot`.

## The Directory Structure of `bsroot` 

- `/dnsmasq.conf`: The dnsmasq config file.

- `/registry.yml`: The Docker registry config file.

- `/registry/`: The directory mounted to bootstrapper container as
  registry volume. It is created by the Docker registry service
  running inside the bootstrapper container.

## Build and Run

The real bootstrapper image will contain several services, just in the
current early stage I write a Dockerfile as an example that describes
only one service, the Docker registry.  To build a Docker image from
this Dockerfile:

```
sudo docker build -t registry -f registry.Dockerfile .
```

To run the bootstrapper as a Docker container named `registry`:
```
sudo docker run -d --privileged -p 5000:5000 --name registry -v $(pwd)/bsroot:/bsroot registry
```

Then we should be able to push an image into it:
```
sudo docker tag hello-world localhost:5000/hello
sudo docker push localhost:5000/hello
```

FROM ubuntu:14.04
ADD ./dhcp.test /dhcp.test
CMD /dhcp.test -indocker

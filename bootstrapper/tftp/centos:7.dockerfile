FROM centos:7
COPY . /tmp
CMD /tmp/tftp.test -indocker

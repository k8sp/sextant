FROM ubuntu:14.04

RUN mkdir -p /opt/nvidia/

# Nvidia drivers setup
WORKDIR /opt/nvidia/
COPY libraries-367.35.tar.bz2 /opt/nvidia
COPY modules-1068.9.0-367.35.tar.bz2 /opt/nvidia
COPY tools-367.35.tar.bz2 /opt/nvidia
RUN tar -xf libraries-367.35.tar.bz2
RUN tar -xf modules-1068.9.0-367.35.tar.bz2
RUN tar -xf tools-367.35.tar.bz2

CMD insmod /opt/nvidia/nvidia.ko
CMD insmod /opt/nvidia/nvidia-uvm.ko

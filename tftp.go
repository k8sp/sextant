package config

import (
        "os/exec"
      	"github.com/k8sp/auto-install/config"
)

linuxdis := config.LinuxDistro()   
if _,e := exec.Command("/bin/sh","-c",`systemctl status tftpd-hpa | grep "not-found"`).StdoutPipe(); e == nil; linuxdis == "ubuntu"
{
	config.Cmd("apt-get", "install", "tftp-hpa")
}
else if _,e := exec.Command("/bin/sh","-c",`systemctl status tftp | grep "not-found"`).StdoutPipe(); e == nil; linuxdis == "centos"
{                 
    config.Cmd("yum", "install", "tftp-server")  
}
else if linuxdis == "coreos"
{
    config.Cmd("docker","run","jumanjiman/tftp-hpa")
}

if _,e := exec.Command("/bin/sh","-c",`systemctl status tftpd-hpa | grep "inactive"`).StdoutPipe(); e == nil; linuxdis == "ubuntu"
{
	config.Cmd("service","tftpd-hpa","restart")
}
else if _,e := exec.Command("/bin/sh","-c",`systemctl status tftp | grep "inactive"`).StdoutPipe(); e == nil; linuxdis == "centos"
{
	config.Cmd("service","tftp","restart")
}

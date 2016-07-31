package tftp

import (
        //"os/exec"
        "log"
      	"github.com/k8sp/auto-install/config"
      	"github.com/k8sp/auto-install/bootstrapper/cmd"
)
func Tftp_install(){
	const (
		centos = "centos"
		ubuntu = "ubuntu"
	)
	
	linuxdis := config.LinuxDistro()   
	if linuxdis == ubuntu 
	{
		cmd.Run("apt-get","update")
		cmd.Run("apt-get", "-y", "install", "tftp-hpa")
	}
	else if linuxdis == centos 
	{
		cmd.Run("yum", "-y", "install", "tftp-server")
		//cmd.Run("yum", "-y", "install", "xinetd")
	}
	else
	{
		log.Panicf("Unsupported OS: %s", linuxdis)
	}
	
	switch linuxdis{
	case ubuntu:
		cmd.Run("service","tftpd-hpa","restart")
	case centos:
		cmd.Run("chkconfig","tftp","xinetd","on")
		cmd.Run("service","xinetd","restart")
		}

}



/*
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
*/

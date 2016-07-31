package tftp

import (
        //"os/exec"
        "log"

      	"github.com/k8sp/auto-install/config"
      	"github.com/k8sp/auto-install/bootstrapper/cmd"
      	//"github.com/topicai/candy"
)
func Tftp_install(){
	const (
		centos = "centos"
		ubuntu = "ubuntu"
	)
	
	dist := config.LinuxDistro()   
	if dist != centos && dist != ubuntu {
		log.Panicf("Unsupported OS: %s", dist)
	}

	switch dist {
	case centos:
		cmd.Run("yum", "-y", "install", "tftp-server")
	case ubuntu:
		cmd.Run("apt-get","update")
		cmd.Run("apt-get", "-y", "install", "tftp-hpa")
	}

	// Note that the installation of nginx packages should have
	// created directory /etc/tftp.
	/*candy.WithCreated("/etc/tftp/tftp.conf", func(w io.Writer) {
		_, e := fmt.Fprint(w, Conf(tmpl, c))
		candy.Must(e)
	})*/

	switch dist{
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

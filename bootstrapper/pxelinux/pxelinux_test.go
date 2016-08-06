package pxelinux

import (
	"flag"
	"testing"
	"fmt"
	"gopkg.in/yaml.v2"
	"io/ioutil"

	"github.com/k8sp/auto-install/bootstrapper/vmtest"
	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
)

var (
	indocker = flag.Bool("indocker", false,
		"Tells that the test is running in a Docker container.")
)

func TestInstall(t *testing.T) {
	if *vmtest.InVM {
		c := &config.Cluster{}
		candy.Must(yaml.Unmarshal([]byte(config.ExampleYAML), c))

		Install()

		switch config.LinuxDistro() {
		case "ubuntu":
			{
	                var para="default coreos\n\nlabel coreos\n\tkernel coreos_production_pxe.vmlinuz\n\tappend initrd=coreos_production_pxe_image.cpio.gz cloud-config-url=10.0.2.15/install-coreos.sh"
		        str, err:=ioutil.ReadFile("/var/lib/tftpboot/pxelinux.cfg/default")
			if err != nil{
				fmt.Printf("read fail error=%s\r\n", err.Error())
			}
 			if(string(str) == para){
				fmt.Print("pxelinux pass")
			}else{
				fmt.Print("pxelinux fail")
			}
			}
		case "centos":
			{
                        var para="default coreos\n\nlabel coreos\n\tkernel coreos_production_pxe.vmlinuz\n\tappend initrd=coreos_production_pxe_image.cpio.gz cloud-config-url=10.0.2.15/install-coreos.sh"
                        str, err:=ioutil.ReadFile("/var/lib/tftpboot/pxelinux.cfg/default")
                        if err != nil{
                                fmt.Printf("read fail error=%s\r\n", err.Error())
                        }
                        if(string(str) == para){
                                fmt.Print("pxelinux pass")
                        }else{
                                fmt.Print("pxelinux fail")
                        }

			}
		
		}

	}

}

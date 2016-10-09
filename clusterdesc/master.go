package clusterdesc

import (
	"fmt"
	"strings"
)

// GetMasterHostname fetch master node hostname
func (c Cluster) GetMasterHostname() string {
	var ret []string
	for _, n := range c.Nodes {
		if n.KubeMaster {
			addr := n.Hostname()
			ret = append(ret, fmt.Sprintf("%s", addr))
		}
	}
	return strings.Join(ret, ",")
}

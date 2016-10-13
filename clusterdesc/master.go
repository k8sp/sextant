package clusterdesc

import "fmt"

// GetMasterHostname fetch master node hostname
func (c Cluster) GetMasterHostname() string {
	return c.FetchHostnameRangeWithNodeRole(func(n Node) string {
		if n.KubeMaster {
			addr := n.Hostname()
			return fmt.Sprintf("%s", addr)
		}
		return ""
	})
}

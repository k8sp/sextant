package skydns

import (
	"path"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
)

// DownloadBootImage requires that curl have been installed.
// Download from github.
func DownloadSkyDNSBinary(outDir string) {

	// Download image files.
	cmd.Run("curl", "-o",
		path.Join(outDir, "skydns"),
		"https://github.com/pineking/skydns-binary/raw/master/skydns")
	cmd.Run("chmod", "755", path.Join(outDir, "skydns"))

}

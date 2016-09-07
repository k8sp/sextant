package coreos

import (
	"fmt"
	"os"
	"path"

	"github.com/k8sp/sextant/bootstrapper/cmd"
	"github.com/k8sp/sextant/config"
	"github.com/topicai/candy"
	"github.com/wangkuiyi/sh"
)

func version(channel string) (string, string) {
	if channel == "" {
		channel = "stable"
	}
	url := fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/current/version.txt", channel)
	return channel, <-sh.Cut(sh.Grep(sh.Run("curl", "-s", url), "COREOS_VERSION="), 2, "=")
}

// DownloadBootImage requires that curl and gnupg have been installed.
// Parameter channel could be "stable", "beta", or "alpha".  version
// requires that curl has been installed.
func DownloadBootImage(c *config.Cluster) {
	channel, ver := version(c.CoreOSChannel)

	dir := path.Join(c.NginxRootDir, ver)
	candy.Must(os.MkdirAll(dir, 0644))

	img := "coreos_production_pxe.vmlinuz"
	cpio := "coreos_production_pxe_image.cpio.gz"
	pkey := "CoreOS_Image_Signing_Key.asc"

	// Download image files.
	cmd.Run("curl", "-s", "-o", path.Join(dir, img),
		fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s", channel, ver, img))
	cmd.Run("curl", "-s", "-o", path.Join(dir, cpio),
		fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s", channel, ver, cpio))

	// Download signatures.
	cmd.Run("curl", "-s", "-o", path.Join(dir, img+".sig"),
		fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s.sig", channel, ver, img))
	cmd.Run("curl", "-s", "-o", path.Join(dir, cpio+".sig"),
		fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s.sig", channel, ver, cpio))

	// Download the public key.
	cmd.Run("curl", "-s", "-o", path.Join(dir, pkey),
		fmt.Sprintf("https://coreos.com/security/image-signing-key/%s", pkey))

	// Import the public key.
	cmd.Run("gpg", "--import", "--keyid-format", "LONG", path.Join(dir, pkey))

	// Verify downloaded images.
	cmd.Run("gpg", "--verify", path.Join(dir, img+".sig"), path.Join(dir, img))
	cmd.Run("gpg", "--verify", path.Join(dir, cpio+".sig"), path.Join(dir, cpio))

}

package coreos

import (
	"fmt"
	"path"

	"github.com/k8sp/auto-install/bootstrapper/cmd"
	"github.com/wangkuiyi/sh"
)

// GetVersion returns the most recent version of the specified CoreOS
// channel. channel could be "stable", "beta", or "alpha".  GetVersion
// requires that curl has been installed.
func GetVersion(channel string) string {
	url := fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/current/version.txt", channel)
	return <-sh.Cut(sh.Grep(sh.Run("curl", "-s", url), "COREOS_VERSION="), 2, "=")
}

// DownloadBootImage requires that curl and gnupg have been installed.
func DownloadBootImage(channel, outDir string) {
	ver := GetVersion(channel)

	img := "coreos_production_pxe.vmlinuz"
	cpio := "coreos_production_pxe_image.cpio.gz"
	pkey := "CoreOS_Image_Signing_Key.asc"

	// Download image files.
	cmd.Run("curl", "-o",
		path.Join(outDir, img),
		fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s", channel, ver, img))
	cmd.Run("curl", "-o",
		path.Join(outDir, cpio),
		fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s", channel, ver, cpio))

	// Download signatures.
	cmd.Run("curl", "-o",
		path.Join(outDir, img+".sig"),
		fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s.sig", channel, ver, img))
	cmd.Run("curl", "-o",
		path.Join(outDir, cpio+".sig"),
		fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s.sig", channel, ver, cpio))

	// Download the public key.
	cmd.Run("curl", "-o",
		path.Join(outDir, pkey),
		fmt.Sprintf("https://coreos.com/security/image-signing-key/%s", pkey))

	// Import the public key.
	cmd.Run("gpg", "--import", "--keyid-format", "LONG", path.Join(outDir, pkey))

	// Verify downloaded images.
	cmd.Run("gpg", "--verify", path.Join(outDir, img+".sig"), path.Join(outDir, img))
	cmd.Run("gpg", "--verify", path.Join(outDir, cpio+".sig"), path.Join(outDir, cpio))

}

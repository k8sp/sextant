package initcoreos

import (
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"path"
	"strings"

	"github.com/k8sp/auto-install/config"
	"github.com/topicai/candy"
	"golang.org/x/crypto/openpgp"
)

func getFromHTTP(url string) (string, error) {
	resp, err := http.Get(url)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, err := ioutil.ReadAll(resp.Body)
	return string(body), err
}

func downloadFromHTTP(url string, outfile string) error {
	out, err := os.Create(outfile)
	if err != nil {
		return err
	}
	defer out.Close()
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	_, err2 := io.Copy(out, resp.Body)
	if err2 != nil {
		return err2
	}
	return nil
}

func version(channel string) (string, string) {
	if channel == "" {
		channel = "stable"
	}
	url := fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/current/version.txt", channel)
	channelDesc, err := getFromHTTP(url)
	if err == nil {
		var channelVersion string
		for _, s := range strings.Split(channelDesc, "\n") {
			kv := strings.Split(s, "=")
			if kv[0] == "COREOS_VERSION" {
				channelVersion = kv[1]
			}
		}
		return channel, channelVersion
	}
	return "", ""
}

func gpgCheck(pubkeyfile string, sigfile string, targetfile string) error {
	keyRingReader, err := os.Open(pubkeyfile)
	if err != nil {
		return err
	}
	signature, err := os.Open(sigfile)
	if err != nil {
		return err
	}
	verificationTarget, err := os.Open(targetfile)
	if err != nil {
		return err
	}
	keyring, err := openpgp.ReadArmoredKeyRing(keyRingReader)
	if err != nil {
		return err
	}
	_, err2 := openpgp.CheckDetachedSignature(keyring, verificationTarget, signature)
	if err2 != nil {
		return err2
	}
	return nil
}

// DownloadBootImage requires that curl and gnupg have been installed.
// Parameter channel could be "stable", "beta", or "alpha".  version
// requires that curl has been installed.
func DownloadBootImage(c *config.Cluster) error {
	channel, ver := version(c.CoreOSChannel)

	dir := path.Join(c.NginxRootDir, ver)
	candy.Must(os.MkdirAll(dir, 0755))

	img := "coreos_production_pxe.vmlinuz"
	cpio := "coreos_production_pxe_image.cpio.gz"
	pkey := "CoreOS_Image_Signing_Key.asc"

	// Download image files.
	if e := downloadFromHTTP(fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s", channel, ver, img),
		path.Join(dir, img)); e != nil {
		return e
	}
	if e := downloadFromHTTP(fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s", channel, ver, cpio),
		path.Join(dir, cpio)); e != nil {
		return e
	}

	// Download signatures.
	if e := downloadFromHTTP(fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s.sig", channel, ver, img),
		path.Join(dir, img+".sig")); e != nil {
		return e
	}
	if e := downloadFromHTTP(fmt.Sprintf("https://%s.release.core-os.net/amd64-usr/%s/%s.sig", channel, ver, cpio),
		path.Join(dir, cpio+".sig")); e != nil {
		return e
	}

	// Download the public key.
	if e := downloadFromHTTP(fmt.Sprintf("https://coreos.com/security/image-signing-key/%s", pkey),
		path.Join(dir, pkey)); e != nil {
		return e
	}

	// Verify downloaded images.
	if e := gpgCheck(path.Join(dir, pkey), path.Join(dir, img+".sig"), path.Join(dir, img)); e != nil {
		return e
	}
	if e := gpgCheck(path.Join(dir, pkey), path.Join(dir, cpio+".sig"), path.Join(dir, cpio)); e != nil {
		return e
	}
	return nil
}

// CheckAndDownload check the current coreos version, if not downloaded yet, download it
func CheckAndDownload(c *config.Cluster) error {
	_, ver := version(c.CoreOSChannel)
	dir := path.Join(c.NginxRootDir, ver)
	_, err := os.Stat(dir)
	if err == nil {
		return nil
	}
	// download if version not exist
	if os.IsNotExist(err) {
		return DownloadBootImage(c)
	}
	return err
}

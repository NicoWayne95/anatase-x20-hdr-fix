# Xbox Ally X20 HDR Fix for Anatase OS

An unofficial workaround for HDR not being detected on the **ROG Xbox Ally X (X20)** running **Anatase OS**.

On my X20, KDE originally reported `HDR: incapable` and `Wide Color Gamut: incapable`, even though HDR worked under Windows. The issue was traced to `libdisplay-info 0.3.0` not recognizing HDR metadata inside the panel's DisplayID extension.

This script backports eight upstream HDR-related fixes while keeping the existing `libdisplay-info.so.3` interface. After installing it, KDE recognized HDR, allowed me to enable it, and I could run HDR calibration. I also tested native HDR games using Windows as a comparison.

> **Note:** This script was AI-assisted/vibe-coded and extensively tested on my own X20. It is not an official Anatase fix.

## Installation

Download `X20-HDR-Backport-Installer.sh` into `~/Downloads`.

Open the **Fedora Space** and build the patch:

```bash
fedora
sudo dnf install -y gcc meson ninja-build pkgconf-pkg-config tar xz patch gawk binutils curl
cd ~/Downloads
bash X20-HDR-Backport-Installer.sh --build
```

After `BUILD ERFOLGREICH`, exit the Fedora Space and install it on the **Anatase host**:

```bash
exit
sudo bash ~/Downloads/X20-HDR-Backport-Installer.sh --install
reboot
```

Confirm the installation prompt with `JA`.

### Enable HDR in KDE

Go to **System Settings > Display & Monitor > Display Configuration**. Select the internal display, enable **HDR** and **Wide Color Gamut**, then calibrate HDR.

Check the result with:

```bash
kscreen-doctor -o | grep -iE 'HDR:|Wide Color Gamut:'
```

## Safety and rollback

- Downloads and upstream patches are checked with SHA-256 hashes.
- The original and patched libraries are built separately and checked for exported-symbol compatibility.
- The original files under `/usr` are **not overwritten**. The patched library is placed under `/var` and activated through `/etc`.
- Installation requires `sudo` and explicit confirmation.
- The script currently accepts only `libdisplay-info 0.3.0` and **my specific X20 EDID**. Other panels or firmware revisions may be rejected intentionally.

This is still a **system-wide library override** and is not risk-free. If something goes wrong, run the following on the Anatase host (from a TTY if necessary):

```bash
sudo bash ~/Downloads/X20-HDR-Backport-Installer.sh --rollback
sudo reboot
```

This fixes **native HDR detection**. Gamescope ITM / Windows-style Auto HDR for SDR games is a separate topic.

Upstream work: [libdisplay-info](https://gitlab.freedesktop.org/emersion/libdisplay-info) · [Fedora backport discussion](https://bugzilla.redhat.com/show_bug.cgi?id=2506542)

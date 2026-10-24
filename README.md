# Xbox Ally X20 HDR Fix for Anatase OS

An unofficial workaround for incorrect HDR detection on the **ROG Xbox Ally X (X20)** running **Anatase OS**.

**Version:** v0.1.0 (Experimental)

## The problem

HDR wasn't completely broken on my X20, but it wasn't working correctly either:

- **Steam Game Mode:** Native HDR was already available, but the image looked noticeably darker and the colors more washed out than under Windows.
- **KDE Desktop Mode:** HDR wasn't detected at all. KDE reported `HDR: incapable` and `Wide Color Gamut: incapable`, so I couldn't enable or calibrate it.

The KDE detection issue was traced to `libdisplay-info 0.3.0`, which didn't recognize HDR metadata inside the panel's DisplayID extension. Missing display metadata may also contribute to differences in Game Mode, but that relationship hasn't been isolated or proven yet.

## What the fix changes

This script backports eight upstream HDR-related fixes while keeping the existing `libdisplay-info.so.3` interface. After installing it, KDE changed from `HDR: incapable` to `HDR: disabled`, meaning HDR was finally recognized and could be enabled. I could then enable Wide Color Gamut and run HDR calibration.

I also tested native HDR games using Windows as a comparison. **The confirmed improvement is correct HDR detection and calibration in KDE.** This patch alone does not guarantee that Game Mode's brightness and colors will match Windows in every game.

> **Note:** This script was AI-assisted/vibe-coded and extensively tested on my own X20. It is not an official Anatase fix.

To check which installer version you have, run `bash X20-HDR-Backport-Installer.sh --version`.

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

Confirm the installation prompt with `YES`.

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

This fixes **HDR capability detection in KDE**. Game Mode color and brightness differences may need additional work. Gamescope ITM / Windows-style Auto HDR for SDR games is a separate topic.

Upstream work: [libdisplay-info](https://gitlab.freedesktop.org/emersion/libdisplay-info) · [Fedora backport discussion](https://bugzilla.redhat.com/show_bug.cgi?id=2506542)

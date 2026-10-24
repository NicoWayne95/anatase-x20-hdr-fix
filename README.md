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

### SDR games with HDR enabled in KDE

There is another noticeable improvement in KDE Desktop Mode: **SDR games can now be displayed through KDE's HDR output without any special Steam launch options.** On my X20, **Dead Space 2**, which does not support native HDR, looks noticeably brighter when I play it with HDR enabled in KDE. This was immediately visible during testing.

The technical distinction matters:

- **The patch does not convert SDR games to HDR.** It fixes detection of the OLED panel's HDR capabilities, allowing KDE to enable HDR output in the first place.
- **Wayland does not perform Auto HDR by itself.** It provides color-management interfaces; KDE's **KWin compositor** handles how SDR content is mapped and displayed when HDR output is active.
- **Brighter SDR is not proof of Auto HDR.** KDE can adjust the appearance and reference brightness of SDR content within an HDR output, but that is different from generating additional HDR highlights through inverse tone mapping.
- The appearance of SDR content depends on KDE's HDR calibration and SDR brightness settings. The brighter image is an observation from my X20, not a measured increase in dynamic range.

This explains why fixing HDR detection can also improve the experience with SDR games in KDE, even though the games themselves still render in SDR. **Steam Game Mode uses Gamescope instead of KWin**, so its SDR brightness and color handling must be tested separately. Gamescope ITM, which aims to expand SDR content into HDR, is not part of this library backport.

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

This fixes **HDR capability detection in KDE** and allows KDE to display SDR games through its HDR output once HDR is enabled. Game Mode color and brightness differences may need additional work. Gamescope ITM / Windows-style Auto HDR for SDR games is a separate topic.

Upstream work: [libdisplay-info](https://gitlab.freedesktop.org/emersion/libdisplay-info) · [Fedora backport discussion](https://bugzilla.redhat.com/show_bug.cgi?id=2506542) · [Wayland color management](https://wayland.freedesktop.org/docs/book/Color.html)

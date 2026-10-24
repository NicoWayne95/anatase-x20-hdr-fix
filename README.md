# Xbox Ally X20 HDR Fix for Anatase OS

An experimental fix for HDR detection on the ROG Xbox Ally X (X20) running Anatase OS.

**Version:** v0.1.0 (experimental)

## Why I made this

HDR wasn't working consistently on my X20.

In KDE Desktop Mode, the internal OLED display wasn't recognized as HDR-capable. KDE showed `HDR: incapable` and `Wide Color Gamut: incapable`, so there was no way to enable or calibrate HDR.

Steam Game Mode was different. Native HDR already worked there, but games looked darker and less colorful than they did under Windows 11.

The KDE issue came down to `libdisplay-info 0.3.0`. My panel stores its HDR information in DisplayID 2.0 extensions, and that library version wasn't reporting the information KDE needed.

## Results on my X20

After applying the backport and restarting, KDE changed from reporting HDR as *incapable* to *disabled*. That sounds like a small difference, but it means HDR is now recognized and can actually be enabled.

Here's what I've observed so far:

- **Native HDR in KDE:** HDR can be enabled and calibrated. Games look noticeably brighter and more vibrant, much closer to what I see under Windows 11.
- **SDR games in KDE:** Dead Space 2 looks significantly brighter with KDE's HDR output enabled, even without Steam launch options.
- **Steam Game Mode:** I've also noticed an improvement, but HDR still looks darker and less vibrant than it does in KDE Desktop Mode.

One important detail about SDR games: this fix does **not** add Windows-style Auto HDR. Wayland provides the color-management interfaces, and KDE's KWin compositor handles displaying SDR content within an HDR output. A brighter SDR image doesn't necessarily mean the game has gained extra HDR detail.

Game Mode uses Gamescope instead of KWin. Its HDR output and SDR-to-HDR inverse tone mapping (ITM) are separate from this fix. I'm still looking into why its image doesn't quite match KDE.

## Requirements

This installer is currently limited to the setup I tested:

- An Xbox Ally X20 running Anatase OS.
- The exact internal-panel EDID used for my testing. The installer checks its SHA-256 hash and stops if it doesn't match.
- `libdisplay-info 0.3.0` on the Anatase host.
- A working **Fedora Space** (`fedora` command) for compiling the library.
- An internet connection to download the original source and upstream patches.

Download `X20-HDR-Backport-Installer.sh` and place it in `~/Downloads`.

Anatase is an immutable system, so **build in Fedora Space and install on the Anatase host**. Don't install the build dependencies directly on the host.

### Build tools

The build requires GCC, Meson, Ninja, pkg-config, tar, xz, patch, GNU awk, binutils, curl, coreutils and sed. The installer checks for the individual commands it needs before starting.

Install them **inside Fedora Space**, not on Anatase itself:

```bash
fedora
sudo dnf install -y gcc meson ninja-build pkgconf-pkg-config tar xz patch gawk binutils curl coreutils sed
```

If `fedora` isn't available, you'll need to set up a Fedora Space in Anatase first.

## Installation

### 1. Build the patched library

Stay in Fedora Space and run:

```bash
cd ~/Downloads
bash X20-HDR-Backport-Installer.sh --build
```

Do **not** use `sudo` for the build.

The script downloads `libdisplay-info 0.3.0`, applies eight upstream fixes, builds the original and patched versions, and checks the result against the X20's EDID.

Wait for:

```text
BUILD ERFOLGREICH
```

The compiled files are saved in `~/Downloads/X20-HDR-Backport-Stage`, which is accessible from the Anatase host. The script won't overwrite an existing stage directory.

### 2. Install on Anatase

Leave Fedora Space:

```bash
exit
```

Back on the **Anatase host**, run:

```bash
sudo bash ~/Downloads/X20-HDR-Backport-Installer.sh --install
```

Type `YES` when prompted. Once the script reports that the installation is active, restart the device:

```bash
sudo reboot
```

### 3. Enable and calibrate HDR in KDE

Open **System Settings > Display & Monitor > Display Configuration** and select the internal display.

1. Enable **HDR** and **Wide Color Gamut**.
2. Apply the changes.
3. Run KDE's HDR calibration.

My panel's EDID reports a peak brightness of roughly **1,405 nits**, so I used around **1,400 nits** as my reference during calibration. That is the value reported by my panel, not a measured brightness guarantee or a setting that everyone should copy blindly. Use KDE's calibration preview to check the result.

### 4. Check the result

On the Anatase host:

```bash
bash ~/Downloads/X20-HDR-Backport-Installer.sh --status
```

In a KDE Desktop session, you can also run:

```bash
kscreen-doctor -o | grep -iE 'HDR:|Wide Color Gamut:'
```

Before you enable the options in KDE, they may show as `disabled`. Once enabled, they should report:

```text
HDR: enabled
Wide Color Gamut: enabled
```

## What the installer changes

The installer is deliberately conservative:

- It verifies the downloaded source and patches using fixed SHA-256 checksums.
- It builds the original and patched libraries separately and checks that the existing exported symbols are still present.
- It confirms that the patched library detects HDR PQ and BT.2020 in my original EDID where the unpatched version did not.
- It puts the new library under `/var/lib/x20-hdr-backport` and selects it through `/etc/ld.so.conf.d/00-x20-hdr-backport.conf`.
- It does **not** overwrite the original library files in `/usr`.

This is still a **system-wide shared-library override**, so it isn't risk-free. An incompatible library could affect KDE or other programs that load it.

### Rollback

If you run into problems, return to the Anatase host and use:

```bash
sudo bash ~/Downloads/X20-HDR-Backport-Installer.sh --rollback
sudo reboot
```

If KDE won't start, you may need to do this from a text console (TTY). The rollback removes the loader configuration and restores the original library selection. It leaves the compiled library in `/var` rather than deleting it.

## Notes

I built this installer with help from ChatGPT. Some of the code was AI-generated, but I've tested the build and installation process, HDR detection, and games on my own X20. It is an unofficial workaround, not an Anatase release or a general fix for every X20 panel.

The remaining Game Mode brightness and color differences are still being investigated. This backport fixes KDE's HDR capability detection; it doesn't patch Gamescope.

Installer version:

```bash
bash X20-HDR-Backport-Installer.sh --version
```

Related projects: [libdisplay-info](https://gitlab.freedesktop.org/emersion/libdisplay-info) · [Fedora backport discussion](https://bugzilla.redhat.com/show_bug.cgi?id=2506542) · [Wayland color management](https://wayland.freedesktop.org/docs/book/Color.html)

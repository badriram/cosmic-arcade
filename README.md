# Cosmic Arcade

A gaming-focused image combining [Fedora COSMIC Atomic](https://fedoraproject.org/cosmic/) with userspace patches borrowed from [Bazzite](https://bazzite.gg/). Stock Fedora kernel; gaming stack added on top.

## What's Included

**Patched userspace (from ublue-os/bazzite COPRs):**
- Pipewire (f43 only — falls back to Fedora stock on f44 until upstream catches up)
- Wireplumber, Bluez, Xwayland

**Gaming stack:**
- Steam, Lutris, Gamescope, umu-launcher
- MangoHud, vkBasalt, OBS VkCapture
- ROCm for AMD GPUs
- mesa-va-drivers-freeworld (full codec hardware decode, from rpmfusion)

**From Fedora COSMIC:**
- COSMIC desktop environment
- Clean Fedora base (no KDE/GNOME cruft)
- Stock Fedora kernel

**Shell & Utilities:**
- zsh as default shell with sensible defaults
- eza, btop, fastfetch
- Flatpak with Flathub configured

## Building

```bash
# Build locally
just build

# Or with podman directly
podman build -t cosmic-arcade:44 .
```

## Installation

```bash
# From local build
rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/cosmic-arcade:44

# From GitHub Container Registry
rpm-ostree rebase ostree-unverified-image:docker://ghcr.io/badriram/cosmic-arcade:latest
```

## Rollback

```bash
rpm-ostree rollback
```

## What's NOT Included

This is a streamlined image. It does NOT include:
- ujust commands (Bazzite's CLI utilities)
- Steam Deck / Handheld support (hhd, gamescope-session)
- Waydroid, Sunshine, Cockpit
- Greenboot health checks
- Bazzite's custom kernel and system configuration scripts

For full Bazzite features on COSMIC, use a full Bazzite fork instead.

## License

MIT

#!/bin/bash
# Cosmic Arcade - Gaming packages and system configuration
set -ouex pipefail

FEDORA_VERSION="${FEDORA_VERSION:-44}"

# ============================================================================
# REPOSITORIES
# ============================================================================

dnf5 -y install dnf5-plugins

# Enable Bazzite COPRs
for copr in \
    ublue-os/bazzite \
    ublue-os/bazzite-multilib \
    ublue-os/staging \
    ublue-os/obs-vkcapture; \
do
    dnf5 -y copr enable $copr
    dnf5 -y config-manager setopt "copr:copr.fedorainfracloud.org:${copr////:}".priority=98
done

# Add Terra repo (Mesa)
dnf5 -y install --nogpgcheck --repofrompath 'terra,https://repos.fyralabs.com/terra$releasever' \
    terra-release
dnf5 -y config-manager setopt "terra".enabled=true

# Add RPM Fusion
dnf5 -y install \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VERSION}.noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VERSION}.noarch.rpm

# Add Negativo17 repos
dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-multimedia.repo
mv /etc/yum.repos.d/fedora-multimedia.repo /etc/yum.repos.d/negativo17-fedora-multimedia.repo 2>/dev/null || true
dnf5 -y config-manager addrepo --from-repofile=https://negativo17.org/repos/fedora-steam.repo

# Set repo priorities
dnf5 -y config-manager setopt "*bazzite*".priority=1
dnf5 -y config-manager setopt "*terra*".priority=3 "*terra*".exclude="steam"
# Keep Fedora/bazzite as the source for core mesa, but let mesa-va-drivers-freeworld
# come through from rpmfusion — Fedora's stock mesa-va-drivers is a stub without
# patent codec support.
dnf5 -y config-manager setopt "*rpmfusion*".priority=5 \
    "*rpmfusion*".exclude="mesa mesa-dri-drivers mesa-filesystem mesa-libEGL* mesa-libGL* mesa-libgbm* mesa-libOpenCL* mesa-vulkan-drivers*"

# ============================================================================
# PATCHED SYSTEM PACKAGES (Valve's versions from Bazzite)
# ============================================================================

# Swap to Bazzite's patched packages. The COPRs are priority=1, so the
# resolver may pull patched versions transitively (e.g. wireplumber's pipewire
# dep), making a later explicit swap a no-op. That's fine — assert provenance
# after the fact rather than requiring `swap` itself to have done the work.
dnf5 -y swap --repo=copr:copr.fedorainfracloud.org:ublue-os:bazzite wireplumber wireplumber || true
dnf5 -y swap --repo=copr:copr.fedorainfracloud.org:ublue-os:bazzite-multilib pipewire pipewire || true
dnf5 -y swap --repo=copr:copr.fedorainfracloud.org:ublue-os:bazzite-multilib bluez bluez || true
dnf5 -y swap --repo=copr:copr.fedorainfracloud.org:ublue-os:bazzite-multilib xorg-x11-server-Xwayland xorg-x11-server-Xwayland || true

# TODO(f44): ublue-os/bazzite-multilib has no f44 pipewire build yet (only f43).
# Accept Fedora's stock pipewire on f44 until the COPR catches up. Drop this
# exception once `pipewire` appears on the fedora-44-x86_64 chroot at
# https://copr.fedorainfracloud.org/coprs/ublue-os/bazzite-multilib/
for pkg in wireplumber pipewire bluez xorg-x11-server-Xwayland; do
    from_repo=$(dnf5 repoquery --installed --qf '%{from_repo}' "${pkg}" 2>/dev/null | head -1)
    if [[ "${from_repo}" == *bazzite* ]]; then
        echo "✓ ${pkg} from ${from_repo}"
        continue
    fi
    if [[ "${pkg}" == "pipewire" && "${FEDORA_VERSION}" == "44" ]]; then
        echo "⚠ ${pkg} from '${from_repo}' (no f44 bazzite build yet — accepting Fedora stock)"
        continue
    fi
    echo "FATAL: ${pkg} installed from '${from_repo}', expected a *bazzite* COPR" >&2
    exit 1
done

# Lock patched packages
dnf5 versionlock add \
    pipewire pipewire-alsa pipewire-libs pipewire-pulseaudio \
    wireplumber wireplumber-libs \
    bluez bluez-libs \
    xorg-x11-server-Xwayland \
    mesa-dri-drivers mesa-filesystem mesa-libEGL mesa-libGL \
    mesa-libgbm mesa-va-drivers-freeworld mesa-vulkan-drivers || true

# VA hardware video decode (from rpmfusion — Fedora's mesa-va-drivers is a stub
# without patent codecs)
dnf5 -y install --enable-repo="*rpmfusion*" \
    mesa-va-drivers-freeworld.x86_64 \
    mesa-va-drivers-freeworld.i686

# ============================================================================
# GAMING PACKAGES
# ============================================================================

# Core gaming
# TODO(f44): gamescope on f44 comes from Fedora as a single package, x86_64 only
# (Koji builds gamescope.i686 but Fedora doesn't tag it for multilib release;
# 32-bit gamescope libs aren't needed for normal Steam/Proton use anyway —
# gamescope runs as the x86_64 parent compositor, 32-bit games run as Wine/Proton
# clients inside it). No gamescope-libs subpackage split on Fedora; no
# gamescope-shaders for f44 — gamescope JITs shaders at runtime instead.
# When ublue-os/bazzite-multilib publishes a successful f44 gamescope build,
# revisit (their current builds are failing across all chroots).
dnf5 -y install \
    steam \
    lutris \
    gamescope \
    umu-launcher

# Overlays and capture
# TODO(f44): libobs_*capture.i686 not built for f44 in ublue-os/obs-vkcapture
# COPR. Only relevant for capturing from 32-bit games (rare on modern Proton).
# Revisit when the COPR ships multilib for f44.
dnf5 -y install \
    mangohud.x86_64 \
    mangohud.i686 \
    vkBasalt.x86_64 \
    vkBasalt.i686 \
    libobs_vkcapture.x86_64 \
    libobs_glcapture.x86_64

# Wine/Proton dependencies
dnf5 -y install \
    libFAudio.x86_64 \
    libFAudio.i686

# ROCm for AMD GPUs
dnf5 -y --setopt=install_weak_deps=False install \
    rocm-hip \
    rocm-opencl \
    rocm-clinfo \
    rocm-smi

# Media codecs
dnf5 -y install --enable-repo="*rpmfusion*" --disable-repo="*fedora-multimedia*" \
    libaacs \
    libbdplus \
    libbluray

# ============================================================================
# UTILITIES
# ============================================================================

dnf5 -y install \
    btop \
    fastfetch \
    fish \
    zsh \
    eza \
    gnome-disk-utility \
    vulkan-tools \
    p7zip \
    p7zip-plugins \
    tmux \
    libxcrypt-compat

# Winetricks
curl -Lo /usr/bin/winetricks https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
chmod +x /usr/bin/winetricks

# ============================================================================
# SYSTEM CONFIGURATION
# ============================================================================

# Flathub
mkdir -p /etc/flatpak/remotes.d
curl --retry 3 -Lo /etc/flatpak/remotes.d/flathub.flatpakrepo https://dl.flathub.org/repo/flathub.flatpakrepo

# Copy system files (skeleton configs, etc.)
if [[ -d /ctx/system_files ]]; then
    cp -r /ctx/system_files/* /
fi

# Set zsh as default shell for new users
sed -i 's|^SHELL=.*|SHELL=/bin/zsh|' /etc/default/useradd 2>/dev/null || \
    echo 'SHELL=/bin/zsh' >> /etc/default/useradd

# ============================================================================
# CLEANUP
# ============================================================================

# Disable repos at runtime
for copr in \
    ublue-os/bazzite \
    ublue-os/bazzite-multilib \
    ublue-os/staging \
    ublue-os/obs-vkcapture; \
do
    dnf5 -y copr disable $copr
done

sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/fedora-steam.repo 2>/dev/null || true
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/negativo17-fedora-multimedia.repo 2>/dev/null || true
sed -i 's@enabled=1@enabled=0@g' /etc/yum.repos.d/terra*.repo 2>/dev/null || true

dnf5 clean all
rm -rf /tmp/* /var/tmp/*

echo "Cosmic Arcade build complete"

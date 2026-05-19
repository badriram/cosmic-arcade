# Cosmic Arcade - Gaming image based on Fedora COSMIC
#
# Fedora COSMIC base + bazzite userspace patches (audio/bluetooth/Xwayland from
# ublue-os COPRs) + gaming stack + mesa-freeworld. Stock Fedora kernel.

ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"
ARG BASE_IMAGE="quay.io/fedora-ostree-desktops/cosmic-atomic:${FEDORA_VERSION}"

# Build context
FROM scratch AS ctx
COPY build_files /
COPY system_files /system_files

# Main image
FROM ${BASE_IMAGE}

ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"

# Install gaming packages and configure system
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build.sh

# Verify the image
RUN bootc container lint

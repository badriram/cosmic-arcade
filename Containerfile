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

# arcade-cli builder — compiles the Rust CLI ahead of the main image so we
# don't need rust/cargo in the final ostree.
FROM registry.fedoraproject.org/fedora:${FEDORA_VERSION} AS arcade-cli-builder
RUN dnf5 -y install rust cargo gcc && dnf5 clean all
COPY arcade-cli /src/arcade-cli
WORKDIR /src/arcade-cli
RUN cargo build --release --locked || cargo build --release

# Main image
FROM ${BASE_IMAGE}

ARG FEDORA_VERSION="${FEDORA_VERSION:-44}"

COPY --from=arcade-cli-builder /src/arcade-cli/target/release/arcade-cli /usr/bin/arcade-cli

# Install gaming packages and configure system
RUN --mount=type=cache,dst=/var/cache \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/build.sh

# Verify the image
RUN bootc container lint

# Cosmic Arcade - Justfile

export FEDORA_VERSION := "44"
export IMAGE_NAME := "cosmic-arcade"

# Build the image locally
build:
    podman build \
        --build-arg FEDORA_VERSION={{FEDORA_VERSION}} \
        -t {{IMAGE_NAME}}:{{FEDORA_VERSION}} \
        .

# Build with no cache
build-fresh:
    podman build \
        --no-cache \
        --build-arg FEDORA_VERSION={{FEDORA_VERSION}} \
        -t {{IMAGE_NAME}}:{{FEDORA_VERSION}} \
        .

# Run a shell in the built image
shell:
    podman run -it --rm {{IMAGE_NAME}}:{{FEDORA_VERSION}} /bin/bash

# Show rebase command
rebase:
    @echo "To rebase to this image, run:"
    @echo "  rpm-ostree rebase ostree-unverified-image:containers-storage:localhost/{{IMAGE_NAME}}:{{FEDORA_VERSION}}"

# Clean up build cache
clean:
    podman system prune -f

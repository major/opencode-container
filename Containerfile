# Multi-stage build for opencode container image
# Base image: Fedora 44 (pinned by tag; Renovate's docker manager will add/maintain digest pin)
# Note: Renovate will automatically update the digest for fedora:44 via its native docker manager.

# renovate: datasource=github-releases depName=anomalyco/opencode extractVersion=^v(?<version>.*)$
ARG OPENCODE_VERSION=1.18.2
# renovate: datasource=github-releases depName=cli/cli extractVersion=^v(?<version>.*)$
ARG GH_VERSION=2.96.0
# renovate: datasource=gitlab-releases depName=gitlab-org/cli registryUrl=https://gitlab.com extractVersion=^v(?<version>.*)$
ARG GLAB_VERSION=1.108.0

# ============================================================================
# Builder stage: download and extract opencode, gh, glab binaries
# ============================================================================
FROM registry.fedoraproject.org/fedora:44@sha256:f16f06649313672c20c7f177c8a53c28bba2fc71aa8ca17d5a7df037415e7b40 AS builder

ARG TARGETARCH
ARG OPENCODE_VERSION
ARG GH_VERSION
ARG GLAB_VERSION

# Install minimal build dependencies
# Note: tar, gzip, ca-certificates are already present in fedora:44 base image
RUN dnf install -y --setopt=install_weak_deps=False curl && dnf clean all -y

# Create output directory for binaries
RUN mkdir -p /out/usr/local/bin

# Map TARGETARCH to opencode's naming convention (amd64 -> x64, arm64 -> arm64)
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      OC_ARCH="x64"; \
    else \
      OC_ARCH="$TARGETARCH"; \
    fi && \
    # Download and extract opencode
    curl -fsSL "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-${OC_ARCH}.tar.gz" | \
      tar xzf - -C /out/usr/local/bin && \
    chmod 755 /out/usr/local/bin/opencode && \
    # Download and extract gh (binary at gh_<ver>_linux_<arch>/bin/gh)
    curl -fsSL "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${TARGETARCH}.tar.gz" | \
      tar xzf - && \
    mv "gh_${GH_VERSION}_linux_${TARGETARCH}/bin/gh" /out/usr/local/bin/gh && \
    chmod 755 /out/usr/local/bin/gh && \
    # Download and extract glab (defensive: find the binary in the tarball)
    curl -fsSL "https://gitlab.com/gitlab-org/cli/-/releases/v${GLAB_VERSION}/downloads/glab_${GLAB_VERSION}_linux_${TARGETARCH}.tar.gz" | \
      tar xzf - -C /tmp && \
    find /tmp -name glab -type f -executable 2>/dev/null | head -1 | xargs -I {} mv {} /out/usr/local/bin/glab && \
    test -f /out/usr/local/bin/glab || { echo "ERROR: glab binary not found in tarball"; exit 1; } && \
    chmod 755 /out/usr/local/bin/glab

# ============================================================================
# Final stage: minimal runtime image with opencode and its dependencies
# ============================================================================
FROM registry.fedoraproject.org/fedora:44@sha256:f16f06649313672c20c7f177c8a53c28bba2fc71aa8ca17d5a7df037415e7b40

# Install runtime dependencies only
# Note: grep, bash, ca-certificates are already present in fedora:44 base image
RUN dnf install -y --nodocs --setopt=install_weak_deps=False \
      git ripgrep curl jq fd-find openssh-clients && \
    dnf clean all -y

# Create non-root user for running opencode
RUN useradd -m -u 1000 opencode

LABEL org.opencontainers.image.source="https://github.com/major/opencode-container" \
      org.opencontainers.image.description="opencode CLI with git, ripgrep, gh, and glab"

# Copy binaries from builder stage
COPY --from=builder /out/usr/local/bin/ /usr/local/bin/

# Set working directory
WORKDIR /workspace

# Switch to non-root user
USER opencode

# Default command: run opencode
# Using CMD (not ENTRYPOINT) allows `docker run -it <image> bash` for interactive shells
CMD ["opencode"]

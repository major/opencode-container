# opencode-container

A minimal OCI container image bundling the [opencode](https://github.com/anomalyco/opencode) CLI and its runtime dependencies (git, ripgrep, gh, glab) on Fedora 44.

## Build

Build locally for your platform:
```bash
docker build -f Containerfile -t opencode-container .
```

Build for multiple architectures (requires buildx; add `--push` to publish to a
registry since multi-platform results can't be `--load`ed locally as a single
image):
```bash
docker buildx build -f Containerfile --platform linux/amd64,linux/arm64 -t opencode-container --push .
```

## Run

Run the image with your current directory mounted as `/workspace`:
```bash
docker run -it --rm -v $PWD:/workspace opencode-container
```

Or open a shell:
```bash
docker run -it --rm -v $PWD:/workspace opencode-container bash
```

## Versions

Tool versions are pinned in the `Containerfile` and automatically kept up to date via Renovate.

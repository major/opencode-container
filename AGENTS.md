# opencode-container

Multi-stage `Containerfile` that builds a minimal Fedora 44 OCI image bundling
the `opencode` CLI plus git, ripgrep, gh, and glab. There is no application
code — the Containerfile is the entire source of truth.

## Build / verify

```bash
docker build -f Containerfile -t opencode-container .
```

Multi-arch build (matches CI, requires buildx):
```bash
docker buildx build -f Containerfile --platform linux/amd64,linux/arm64 -t opencode-container --push .
```

There are no unit tests. The only verification is that the image builds
successfully (see `.github/workflows/pr-check.yml`, which builds for both
platforms on any PR touching `Containerfile`, `renovate.json`, or workflows).

## Structure

- Builder stage downloads/extracts pinned `opencode`, `gh`, `glab` binaries
  into `/out/usr/local/bin`.
- Final stage installs runtime-only deps (`git ripgrep curl jq fd-find
  openssh-clients`) on `registry.fedoraproject.org/fedora:44`, copies the
  binaries, creates a non-root `opencode` user (uid 1000), and runs as that
  user. `WORKDIR /workspace` is where callers mount their project.
- `CMD ["opencode"]` (not `ENTRYPOINT`) so `docker run ... opencode-container
  bash` still works for a shell.

## Version pinning (Renovate)

Tool versions live as `ARG ..._VERSION` in the `Containerfile`, each preceded
by a `# renovate: datasource=... depName=... extractVersion=...` comment.
`renovate.json` defines a custom regex manager that reads these comments —
**if you add a new pinned tool, add a matching `# renovate:` comment above its
ARG or Renovate won't track it.**

- `anomalyco/opencode`, `cli/cli` (gh), `gitlab-org/cli` (glab), and Fedora
  base image digest bumps: minor/patch/digest updates automerge; major bumps
  need manual review.
- The base image tag (`fedora:44`) is pinned by tag; Renovate's native docker
  manager maintains the digest, not the custom regex manager.

## CI

- `pr-check.yml`: builds both platforms on PRs (no push) — this is the PR gate.
- `build.yml`: builds and pushes to `ghcr.io/<repo>` on push to `main`, weekly
  (Mon 6am UTC) as a safety net, and via manual dispatch. Tags: `latest`
  (default branch only), short SHA, and `YYYYMMDD`.

## Misc

- `.slim/deepwork/opencode-container.md` is deepwork-skill state, not project
  docs — ignore unless doing deepwork-tracked work.

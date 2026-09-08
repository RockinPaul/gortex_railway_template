# Changelog

## 2026-09 — initial release, gortex v0.64.1

- `gortex` service from `Dockerfile`: `alpine:3.21`, git, the upstream release binary `gortex_linux_<arch>.tar.gz` v0.64.1 verified against the release checksums. `entrypoint.sh` clones and fast-forwards `GORTEX_REPOS`, tracks them, runs a `git pull` loop every `GORTEX_SYNC_INTERVAL` seconds, and starts `gortex daemon start --http-addr [::]:$PORT --tools $GORTEX_TOOLS` with the store at `/data/data/gortex/store.sqlite`.
- `web` service from `Dockerfile.web`: gortexhq/web at commit `9b0b48a`, patched at build time (`web/patch.js`: standalone output, relative API base, dashboard label), served by Caddy with basic auth and server-side bearer injection for `/v1/*`.
- Volume at `/data` on `gortex`. Healthchecks `/healthz` on both services.

### Upgrading an existing deployment

The graph store is rebuilt from the clones if gortex's schema changes, so there is nothing to migrate by hand: applying a template update redeploys both services and never touches the volume. If a new gortex release cannot open an old store, delete `/data/data/gortex` in the service shell and restart; the repos are re-indexed from the clones. Check `/healthz` and `/v1/health` afterwards; the latter reports the running version and node count.

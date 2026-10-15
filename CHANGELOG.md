# Changelog

## 2026-10 — gortex v0.64.8

- `gortex` runs the v0.64.8 release binary (was v0.64.1). The checksums come from the release's `checksums.txt`, whose cosign signature was issued to gortex's own `release.yml` workflow at the `v0.64.8` tag. Picks up the `generate_skill` output-directory fix (GHSA-jh93-48gg-gqjp), exact host matching for vendor-key fallbacks, and upstream's new browser-origin guard.
- **`web/Caddyfile` now enforces same-origin on `/v1`.** From v0.64.8 the daemon refuses every request that carries a browser `Origin` header, even with a valid token, unless `--http-allowed-origin` names it, and browsers send `Origin` on the UI's own same-origin POSTs. Caddy now answers 403 to a `/v1` request whose `Origin` is not the UI's own site and strips `Origin` from the rest before adding the bearer token. Cross-site pages stay blocked; the UI keeps working without the daemon having to know the web domain.

### Upgrading an existing deployment

Nothing to change. Both services redeploy; the volume and the graph store are kept (verified: a v0.64.1 store with a tracked repository served the same graph under v0.64.8). Update both services together: a v0.64.8 daemon behind the previous `web` image refuses the UI's POST requests until `web` is redeployed.

## 2026-09 — initial release, gortex v0.64.1

- `gortex` service from `Dockerfile`: `alpine:3.21`, git, the upstream release binary `gortex_linux_<arch>.tar.gz` v0.64.1 verified against the release checksums. `entrypoint.sh` clones and fast-forwards `GORTEX_REPOS`, tracks them, runs a `git pull` loop every `GORTEX_SYNC_INTERVAL` seconds, and starts `gortex daemon start --http-addr [::]:$PORT --tools $GORTEX_TOOLS` with the store at `/data/data/gortex/store.sqlite`.
- `web` service from `Dockerfile.web`: gortexhq/web at commit `9b0b48a`, patched at build time (`web/patch.js`: standalone output, relative API base, dashboard label), served by Caddy with basic auth and server-side bearer injection for `/v1/*`.
- Volume at `/data` on `gortex`. Healthchecks `/healthz` on both services.

### Upgrading an existing deployment

The graph store is rebuilt from the clones if gortex's schema changes, so there is nothing to migrate by hand: applying a template update redeploys both services and never touches the volume. If a new gortex release cannot open an old store, delete `/data/data/gortex` in the service shell and restart; the repos are re-indexed from the clones. Check `/healthz` and `/v1/health` afterwards; the latter reports the running version and node count.

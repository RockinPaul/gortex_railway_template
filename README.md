# gortex Railway Template

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/deploy/gortex?referralCode=YqmMB-&utm_medium=integration&utm_source=template&utm_campaign=generic)

Railway template for [gortex](https://github.com/zzet/gortex), the code-intelligence engine for AI agents: it indexes repositories into a graph and answers questions about symbols, call chains, usages, contracts, and impact through MCP, so agents read what they need instead of whole files. This template runs gortex's own daemon as a hosted service for agents that do not have the code on their machine, with an optional web UI. It deploys:

- `gortex`: the daemon, from a pinned upstream release binary, serving MCP Streamable HTTP at `/mcp` and the JSON API at `/v1/*`, with a volume for the clones and the graph store
- `web`: the upstream web UI behind a username and password, proxying the API to the daemon over Railway's private network

No database and no LLM key are needed. gortex parses code with tree-sitter and keeps its graph in an embedded SQLite store on the volume.

## Which repositories get indexed

`GORTEX_REPOS` on the `gortex` service is a comma-separated list of git URLs, or `name=url` pairs. On every start the entrypoint clones each repo into `/data/repos/<name>` (or fast-forwards it if it exists), registers it with `gortex track`, and then starts the daemon, which indexes everything it tracks. An entry that cannot be cloned is skipped with a warning in the logs; the other repos still come up. A background loop pulls every `GORTEX_SYNC_INTERVAL` seconds, and the daemon reindexes changed files incrementally. The default is gortex's own repository, so a fresh deploy has a real codebase to explore; replace it with yours.

Private repositories: set `GIT_TOKEN` to a token with read access (a GitHub fine-grained token, for example). It is handed to git through a credential helper, never written into a URL or config file. Use plain `https://` URLs.

Removing a URL from the list stops updates but leaves the clone and its index in place. To drop it fully, run `gortex untrack /data/repos/<name>` in the service shell and delete the folder.

## Connect an agent

Copy the `gortex` service's public domain and its `GORTEX_DAEMON_HTTP_TOKEN`.

Claude Code:

```
claude mcp add --transport http gortex https://<gortex-domain>/mcp --header "Authorization: Bearer <token>"
```

OpenCode:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "gortex": {
      "type": "remote",
      "url": "https://<gortex-domain>/mcp",
      "headers": { "Authorization": "Bearer <token>" }
    }
  }
}
```

A local gortex daemon can also federate with the hosted one, so your IDE's gortex sees both local and hosted repos:

```
export GORTEX_HOSTED_TOKEN=<token>
gortex proxy add hosted https://<gortex-domain> --auth-token-env GORTEX_HOSTED_TOKEN --read-only
gortex daemon restart
```

CI and scripts can call the JSON API directly: `GET /v1/health`, `GET /v1/tools`, `POST /v1/tools/<name>`, `GET /v1/stats`, `GET /v1/graph`, `GET /v1/events` (SSE). Every request needs the bearer token; `/healthz` does not.

## The web UI

Open the `web` service's domain and sign in with `WEB_USER` and `WEB_PASSWORD`. The UI is upstream's [gortexhq/web](https://github.com/gortexhq/web) built at a pinned commit. Upstream expects the daemon token in a `NEXT_PUBLIC_*` variable, which Next.js would embed in the JavaScript anyone can download, so this template puts Caddy in front instead: Caddy requires the password, proxies `/v1/*` to the daemon over the private network, and adds the bearer token on the server side. Three small build-time patches make that work, applied by `web/patch.js` to the pinned commit: standalone output, a relative API base so the browser calls `/v1/*` on the UI's own origin, and the dashboard label that names the server. Each patch fails the build if upstream moves the line it targets, so a UI bump cannot silently ship an unpatched build.

The UI is optional. Delete the `web` service if you only need MCP and the API.

## Tools

`GORTEX_TOOLS=readonly` publishes gortex's read-only surface: navigation, search, call chains, usages, impact, contracts, review, analysis, and nothing that writes files. That is deliberate: edit tools would modify the server's clones, not your checkout, and dirty clones cannot be fast-forwarded. Other presets are `core`, `full`, `nav`, `localization`, or an explicit list; see upstream's [MCP docs](https://github.com/zzet/gortex/blob/main/docs/mcp.md). Changing the variable restarts the daemon.

## Variables

`gortex` service:

| Variable | Default | Purpose |
|---|---|---|
| `GORTEX_DAEMON_HTTP_TOKEN` | generated | Bearer token for `/mcp` and `/v1/*`. Read natively by gortex. The daemon refuses to start on a public bind without it. |
| `GORTEX_REPOS` | `https://github.com/zzet/gortex` | Repositories to clone, track, and index. `url` or `name=url`, comma-separated. |
| `GORTEX_TOOLS` | `readonly` | Published MCP tool preset. |
| `GORTEX_SYNC_INTERVAL` | `300` | Seconds between `git pull` rounds. `0` disables syncing. |
| `PORT` | `7411` | Listening port for the public domain and the private network. |
| `GIT_TOKEN` | unset | Read token for private `https://` repositories. |
| `GORTEX_DAEMON_MEMLIMIT` | unset | Soft memory cap for the daemon, for example `4GiB`; read natively by gortex. Indexing memory scales with repo size. |

`web` service:

| Variable | Default | Purpose |
|---|---|---|
| `WEB_USER` | `admin` | Username for the UI. |
| `WEB_PASSWORD` | generated | Password for the UI. |
| `GORTEX_DAEMON_HTTP_TOKEN` | `${{gortex.GORTEX_DAEMON_HTTP_TOKEN}}` | Token Caddy adds to proxied API calls. |
| `GORTEX_UPSTREAM` | `http://${{gortex.RAILWAY_PRIVATE_DOMAIN}}:7411` | The daemon over the private network. |
| `PORT` | `8080` | Listening port. |
| `RAILWAY_DOCKERFILE_PATH` | `Dockerfile.web` | Selects the UI image. |

## Data on the volume

```
/data/repos/<name>/                  git clones
/data/data/gortex/store.sqlite       graph store (indexes survive restarts)
/data/config/gortex/config.yaml      tracked repos
/data/cache/gortex/                  daemon state, logs
```

Everything under `/data` can be deleted; the next start clones and indexes again. Sizing: gortex's own repo (4,800 files) indexed in under thirty seconds into a 220 MB store; upstream reports 580 MB peak memory for VS Code and 5 GB for the Linux kernel.

## Upgrading gortex

Bump `GORTEX_VERSION` and the two checksums in `Dockerfile` from the release's `checksums.txt`. For the UI, bump `WEB_COMMIT` in `Dockerfile.web`. Merging to `main` notifies everyone who deployed the template. Note breaking changes in `CHANGELOG.md`.

## Files

- `Dockerfile`: `alpine` plus git and the verified gortex release binary
- `entrypoint.sh`: clones or pulls and tracks each repo, starts the sync loop, then runs `gortex daemon start` with `--http-addr [::]:$PORT`
- `askpass.sh`: git credential helper that answers with `GIT_TOKEN`
- `Dockerfile.web`, `web/patch.js`, `web/Caddyfile`, `web/entrypoint.sh`: the UI image
- `TEMPLATE_OVERVIEW.md`: the marketplace description
- `CHANGELOG.md`: what changed and how to upgrade an existing deployment

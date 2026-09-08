# Deploy and Host gortex on Railway

gortex is the open-source code-intelligence engine for AI coding agents. It parses repositories with tree-sitter into a graph of symbols, calls, usages, and contracts, and serves precise answers over MCP, so an agent reads the ten lines it needs instead of the whole file and spends up to fifty times fewer tokens. This template runs gortex 0.64.1 as a hosted daemon with a persistent volume, plus the upstream web UI behind a password.

## About Hosting gortex

Hosting gortex on Railway means one daemon service and one optional UI service. The daemon runs the pinned upstream release binary, clones the repositories you list in a variable into its volume, indexes them, keeps them synced with git, and serves MCP Streamable HTTP at `/mcp` and a JSON API at `/v1/*`, both protected by a bearer token generated at deploy time. The UI service builds gortex's web app and puts Caddy in front of it: people sign in with a username and password, and Caddy forwards API calls to the daemon over Railway's private network with the token added server-side, so the token never reaches a browser. There is no database and no LLM key; the graph lives in an embedded SQLite store on the volume.

## Common Use Cases

- Code intelligence for cloud coding agents and CI bots that do not have the repository on disk
- One shared, always-warm index of a team's repositories for every agent and IDE, with cross-repo call chains and contracts
- A read-only code map for review bots: impact analysis, usages, and contracts without granting write access

## Dependencies for gortex Hosting

- A Railway account
- Git URLs of the repositories to index, and a read token for private ones
- An MCP client that supports remote HTTP servers with custom headers, such as Claude Code, OpenCode, or Cursor, or a local gortex daemon federating with the hosted one

### Deployment Dependencies

- gortex upstream repository: https://github.com/zzet/gortex
- gortex server and MCP documentation: https://github.com/zzet/gortex/blob/main/docs/server.md
- gortex web UI: https://github.com/gortexhq/web
- Template repository: https://github.com/RockinPaul/gortex_railway_template

### Implementation Details

- `gortex`: built from the template repo's Dockerfile (`alpine`, git, checksum-verified `gortex_linux_<arch>` v0.64.1), healthcheck `/healthz`, public domain, volume at `/data`. Starts `gortex daemon start --http-addr [::]:7411 --tools readonly` after cloning and tracking `GORTEX_REPOS`; the token comes from `GORTEX_DAEMON_HTTP_TOKEN`.
- `web`: built from `Dockerfile.web` (upstream UI at a pinned commit, Next.js standalone, Caddy), healthcheck `/healthz`, public domain, `WEB_USER` / `WEB_PASSWORD`.
- Agents connect to `https://<gortex-domain>/mcp` with `Authorization: Bearer <token>`. Claude Code: `claude mcp add --transport http gortex https://<gortex-domain>/mcp --header "Authorization: Bearer <token>"`.
- The default `GORTEX_REPOS` is gortex's own repository, indexed in under thirty seconds, so the deploy is explorable immediately. Replace it with your repositories; private ones use `GIT_TOKEN`.

## Why Deploy gortex on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying gortex on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

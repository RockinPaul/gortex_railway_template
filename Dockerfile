# gortex code-intelligence daemon for Railway.
# Upgrade gortex by bumping GORTEX_VERSION and the two checksums (from the release's checksums.txt).
FROM alpine:3.21

ARG TARGETARCH=amd64
ARG GORTEX_VERSION=v0.64.1
ARG GORTEX_SHA256_AMD64=e2fa94233c49f78abd4edf6d1f2e37424a2ae2ef13fc3bc294171880a9ec3e00
ARG GORTEX_SHA256_ARM64=d60ece46f2899e423df9b5c5695308b8f8b04ff9dea534facee49044b22be6da

RUN apk add --no-cache git ca-certificates curl \
 && case "$TARGETARCH" in amd64) sum="$GORTEX_SHA256_AMD64" ;; arm64) sum="$GORTEX_SHA256_ARM64" ;; *) echo "unsupported arch $TARGETARCH" >&2; exit 1 ;; esac \
 && curl -fsSL -o /tmp/gortex.tgz "https://github.com/zzet/gortex/releases/download/${GORTEX_VERSION}/gortex_linux_${TARGETARCH}.tar.gz" \
 && echo "${sum}  /tmp/gortex.tgz" | sha256sum -c - \
 && tar -xzf /tmp/gortex.tgz -C /usr/local/bin gortex \
 && rm /tmp/gortex.tgz \
 && gortex version

COPY entrypoint.sh askpass.sh /app/
RUN chmod +x /app/entrypoint.sh /app/askpass.sh

# Everything gortex persists lands under /data (the volume) through the XDG variables.
# Socket and pid file stay ephemeral: a pid file left on the volume by an unclean stop says pid 1,
# which always exists in a container, and the daemon would refuse to start.
ENV XDG_CONFIG_HOME=/data/config \
    XDG_DATA_HOME=/data/data \
    XDG_CACHE_HOME=/data/cache \
    GORTEX_DAEMON_SOCKET=/tmp/gortex.sock \
    GORTEX_DAEMON_PIDFILE=/tmp/gortex.pid \
    GORTEX_TELEMETRY=0 \
    GORTEX_REPOS=https://github.com/zzet/gortex \
    GORTEX_TOOLS=readonly \
    GORTEX_SYNC_INTERVAL=300 \
    PORT=7411
EXPOSE 7411
ENTRYPOINT ["/app/entrypoint.sh"]

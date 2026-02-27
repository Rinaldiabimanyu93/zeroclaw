# syntax=docker/dockerfile:1.7
# rebuild v3

# ── Stage 1: Build ────────────────────────────────────────────
FROM rust:1.93-slim@sha256:9663b80a1621253d30b146454f903de48f0af925c967be48c84745537cd35d8b AS builder

WORKDIR /app

# Install build dependencies
RUN apt-get update && apt-get install -y \
        pkg-config \
    && rm -rf /var/lib/apt/lists/*

# 1. Copy manifests to cache dependencies
COPY Cargo.toml Cargo.lock ./
COPY crates/robot-kit/Cargo.toml crates/robot-kit/Cargo.toml
# Create dummy targets declared in Cargo.toml so manifest parsing succeeds.
RUN mkdir -p src benches crates/robot-kit/src \
    && echo "fn main() {}" > src/main.rs \
    && echo "fn main() {}" > benches/agent_benchmarks.rs \
    && echo "pub fn placeholder() {}" > crates/robot-kit/src/lib.rs
RUN cargo build --release --locked
RUN rm -rf src benches crates/robot-kit/src

# 2. Copy only build-relevant source paths
COPY src/ src/
COPY benches/ benches/
COPY crates/ crates/
COPY firmware/ firmware/
COPY web/ web/
# Keep release builds resilient when frontend dist assets are not prebuilt in Git.
RUN mkdir -p web/dist && \
    if [ ! -f web/dist/index.html ]; then \
      printf '%s\n' \
        '<!doctype html>' \
        '<html lang="en">' \
        '  <head>' \
        '    <meta charset="utf-8" />' \
        '    <meta name="viewport" content="width=device-width,initial-scale=1" />' \
        '    <title>ZeroClaw Dashboard</title>' \
        '  </head>' \
        '  <body>' \
        '    <h1>ZeroClaw Dashboard Unavailable</h1>' \
        '    <p>Frontend assets are not bundled in this build. Build the web UI to populate <code>web/dist</code>.</p>' \
        '  </body>' \
        '</html>' > web/dist/index.html; \
    fi
RUN cargo build --release --locked && \
    cp target/release/zeroclaw /app/zeroclaw && \
    strip /app/zeroclaw

# Prepare runtime directory structure and base config
RUN mkdir -p /zeroclaw-data/.zeroclaw /zeroclaw-data/workspace
RUN printf '%s\n' \
    'api_key = ""' \
    'default_provider = "openrouter"' \
    'default_model = "anthropic/claude-sonnet-4-20250514"' \
    'default_temperature = 0.7' \
    '' \
    '[gateway]' \
    'port = 42617' \
    'host = "[::]"' \
    'allow_public_bind = true' \
    > /zeroclaw-data/.zeroclaw/config.toml

# ── Stage 2: Production Runtime (Debian slim) ─────────────────
FROM debian:trixie-slim AS production

RUN apt-get update && apt-get install -y \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/zeroclaw /usr/local/bin/zeroclaw
COPY --from=builder /zeroclaw-data /zeroclaw-data

# Entrypoint script: inject env vars into config at runtime then start daemon
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

RUN chown -R nobody:nogroup /zeroclaw-data

ENV ZEROCLAW_WORKSPACE=/zeroclaw-data/workspace
ENV HOME=/zeroclaw-data
ENV ZEROCLAW_GATEWAY_PORT=42617

WORKDIR /zeroclaw-data
USER nobody
EXPOSE 42617
ENTRYPOINT ["/entrypoint.sh"]

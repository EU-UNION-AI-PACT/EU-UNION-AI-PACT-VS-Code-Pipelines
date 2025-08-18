# DevContainer mit Node + Rust + Wasmtime + optional Nix
FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04

ARG NODE_VERSION=20.14.0
ARG WASMTIME_VERSION=20.0.0
ARG USERNAME=vscode

# Avoid interactive tzdata, etc.
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl wget git build-essential pkg-config libssl-dev ca-certificates \
    python3 python3-pip unzip jq ripgrep fd-find \
    && rm -rf /var/lib/apt/lists/*

# Node (using official tarball to stay independent of nvm)
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${arch}.tar.xz" -o node.tar.xz; \
    tar -xJf node.tar.xz -C /usr/local --strip-components=1; \
    rm node.tar.xz; \
    corepack enable

# Rust toolchain via rustup (gibt maximale Flexibilität)
RUN su - ${USERNAME} -c '\
    curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal --component clippy rustfmt \
' && ln -s /home/${USERNAME}/.cargo/bin/* /usr/local/bin/

# Add wasm32-wasi target + components
RUN su - ${USERNAME} -c '\
    rustup target add wasm32-wasi \
'

# Wasmtime (statisch aus Release)
RUN curl -L "https://github.com/bytecodealliance/wasmtime/releases/download/v${WASMTIME_VERSION}/wasmtime-v${WASMTIME_VERSION}-x86_64-linux.tar.xz" -o /tmp/wasmtime.tar.xz \
    && tar -xJf /tmp/wasmtime.tar.xz -C /tmp \
    && mv /tmp/wasmtime-v${WASMTIME_VERSION}-x86_64-linux/wasmtime /usr/local/bin/wasmtime \
    && rm -rf /tmp/wasmtime*

ENV PATH=/home/${USERNAME}/.cargo/bin:$PATH

# Create workspace dirs
RUN mkdir -p /workspace && chown -R ${USERNAME}:${USERNAME} /workspace
WORKDIR /workspace

# syntax=docker/dockerfile:1.7

FROM debian:bookworm-slim AS builder

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    git \
    xz-utils \
 && rm -rf /var/lib/apt/lists/*

ENV NIX_INSTALLER_NO_MODIFY_PROFILE=1
ENV NIX_CONFIG="experimental-features = nix-command flakes"
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

WORKDIR /src
COPY . .

RUN curl -fsSL https://install.determinate.systems/nix | sh -s -- install linux --init none --no-confirm

ARG FLAKE_ATTR=.#merlinai-proxy

RUN nix build "$FLAKE_ATTR" --accept-flake-config --no-link \
 && out="$(nix path-info "$FLAKE_ATTR" --accept-flake-config)" \
 && mkdir -p /tmp/closure/usr/local/bin \
 && while IFS= read -r path; do cp -a --parents "$path" /tmp/closure; done < <(nix-store -qR "$out") \
 && ln -s "$out/bin/merlinai-proxy" /tmp/closure/usr/local/bin/merlinai-proxy

FROM debian:bookworm-slim AS runtime

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /tmp/closure/ /

ENV HOME=/tmp
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /tmp
EXPOSE 8000
USER 10001:10001

ENTRYPOINT ["/usr/local/bin/merlinai-proxy"]

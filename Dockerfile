# syntax=docker/dockerfile:1.7

FROM nixos/nix:latest AS builder

SHELL ["/bin/sh", "-ec"]

ENV NIX_CONFIG="experimental-features = nix-command flakes"

WORKDIR /src
COPY . .

ARG FLAKE_ATTR=path:.#merlinai-proxy

RUN nix build "$FLAKE_ATTR" --accept-flake-config --no-link \
 && out="$(nix path-info "$FLAKE_ATTR" --accept-flake-config)" \
 && mkdir -p /tmp/closure/usr/local/bin \
 && nix-store -qR "$out" | while IFS= read -r path; do cp -a --parents "$path" /tmp/closure; done \
 && ln -s "$out/bin/merlinai-proxy" /tmp/closure/usr/local/bin/merlinai-proxy

FROM scratch AS runtime

COPY --from=builder /tmp/closure/ /

ENV HOME=/tmp
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /tmp
EXPOSE 8000
USER 10001:10001

ENTRYPOINT ["/usr/local/bin/merlinai-proxy"]

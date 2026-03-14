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
 && find /tmp/closure -type d -name __pycache__ -prune -exec rm -rf {} + \
 && rm -rf /tmp/closure/nix/store/*-python3-*/lib/python3.12/idlelib \
 && rm -rf /tmp/closure/nix/store/*-python3-*/lib/python3.12/test \
 && rm -rf /tmp/closure/nix/store/*-python3-*/lib/python3.12/tkinter \
 && rm -rf /tmp/closure/nix/store/*-python3-*/lib/python3.12/turtledemo \
 && rm -rf /tmp/closure/nix/store/*-python3-*/lib/python3.12/ensurepip \
 && rm -rf /tmp/closure/nix/store/*-python3-*/lib/python3.12/venv \
 && rm -rf /tmp/closure/nix/store/*-python3-*/lib/python3.12/pydoc_data \
 && rm -rf /tmp/closure/nix/store/*-python3-*/lib/python3.12/config-* \
 && rm -rf /tmp/closure/nix/store/*-python3-*/include \
 && rm -f /tmp/closure/nix/store/*-python3-*/bin/idle /tmp/closure/nix/store/*-python3-*/bin/idle3 \
 && rm -f /tmp/closure/nix/store/*-python3-*/bin/pydoc /tmp/closure/nix/store/*-python3-*/bin/pydoc3 \
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

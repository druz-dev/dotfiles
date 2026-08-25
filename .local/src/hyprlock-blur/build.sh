#!/usr/bin/env bash
# Build hyprlock-blur and install it, plus the hyprlock-live wrapper, into
# ~/.local/bin (override with PREFIX_BIN=/somewhere/bin).
set -euo pipefail
cd "$(dirname "$0")"

bindir=${PREFIX_BIN:-$HOME/.local/bin}

wayland-scanner client-header wlr-layer-shell-unstable-v1.xml wlr-layer-shell-unstable-v1-client-protocol.h
wayland-scanner private-code  wlr-layer-shell-unstable-v1.xml wlr-layer-shell-unstable-v1-protocol.c

cc -O2 -Wall -Wextra -o hyprlock-blur main.c wlr-layer-shell-unstable-v1-protocol.c \
    $(pkg-config --cflags --libs wayland-client)

install -Dm755 hyprlock-blur "$bindir/hyprlock-blur"
install -Dm755 hyprlock-live "$bindir/hyprlock-live"
echo "installed $bindir/hyprlock-blur and $bindir/hyprlock-live"

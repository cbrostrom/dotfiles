#!/usr/bin/env bash

has() { command -v "$1" >/dev/null 2>&1; }
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux() { [[ "$(uname -s)" == "Linux" ]]; }
is_debian() { is_linux && has apt-get; }
is_arch() { is_linux && has pacman; }
is_fedora() { is_linux && has dnf; }

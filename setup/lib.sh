#!/usr/bin/env bash

log() { printf '[dotfiles] %s\n' "$*"; }
info() { log "$@"; }
ok() { printf '[dotfiles] ok: %s\n' "$*"; }
skip() { printf '[dotfiles] skip: %s\n' "$*"; }
warn() { printf '[dotfiles] warning: %s\n' "$*" >&2; }
err() { printf '[dotfiles] error: %s\n' "$*" >&2; }
die() { printf '[dotfiles] error: %s\n' "$*" >&2; exit 1; }

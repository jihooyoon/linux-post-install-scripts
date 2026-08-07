#!/bin/sh
# install-lotus-ubuntu-based.sh — BẢN DRAFT: chỉ in thông báo, không làm gì thật.
# Script thật: sudo ./atom-scripts/install-lotus-ubuntu-based.sh
# Cài bộ gõ tiếng Việt Lotus cho fcitx5 + env

set -e

info() { printf '\033[1;34m[lotus]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }

# Bản draft: không kiểm tra root (script thật yêu cầu sudo).

info "draft-install-lotus-ubuntu-based.sh được gọi — args nhận được: '$*'"
info "Stub: sẽ cài bộ gõ Lotus + cấu hình env fcitx5"
ok "DRAFT: Hoàn tất draft-install-lotus-ubuntu-based.sh"

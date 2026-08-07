#!/bin/sh
# enable-flatpak-flathub-deb.sh — BẢN DRAFT: chỉ in thông báo, không làm gì thật.
# Script thật: sudo ./atom-scripts/enable-flatpak-flathub-deb.sh
# Cài Flatpak + Flathub

set -e

info() { printf '\033[1;34m[flatpak]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }

# Bản draft: không kiểm tra root (script thật yêu cầu sudo).

info "draft-enable-flatpak-flathub-deb.sh được gọi — args nhận được: '$*'"
info "Stub: sẽ cài Flatpak + Flathub"
ok "DRAFT: Hoàn tất draft-enable-flatpak-flathub-deb.sh"

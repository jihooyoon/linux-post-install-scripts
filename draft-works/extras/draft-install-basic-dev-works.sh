#!/bin/sh
# install-basic-dev-works.sh — BẢN DRAFT: chỉ in thông báo, không làm gì thật.
# Script thật: sudo ./extras/install-basic-dev-works.sh
# Cài Node.js LTS (NodeSource)

set -e

info() { printf '\033[1;34m[dev-tools]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }

# Bản draft: không kiểm tra root (script thật yêu cầu sudo).

info "draft-install-basic-dev-works.sh được gọi — args nhận được: '$*'"
info "Stub: sẽ cài Node.js LTS từ NodeSource"
ok "DRAFT: Hoàn tất draft-install-basic-dev-works.sh"

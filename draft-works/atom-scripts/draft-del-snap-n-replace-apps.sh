#!/bin/sh
# del-snap-n-replace-apps.sh — BẢN DRAFT: chỉ in thông báo, không làm gì thật.
# Script thật: sudo ./atom-scripts/del-snap-n-replace-apps.sh
# Gỡ toàn bộ snap packages và snapd, cài lại Firefox .deb + pin Thunderbird tránh snap

set -e

info() { printf '\033[1;34m[del-snap]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[OK]\033[0m     %s\n' "$*"; }
warn() { printf '\033[1;33m[WARN]\033[0m   %s\n' "$*"; }

# Bản draft: không kiểm tra root (script thật yêu cầu sudo).

info "draft-del-snap-n-replace-apps.sh được gọi — args nhận được: '$*'"
info "Stub: sẽ gỡ snap + snapd, cài Firefox .deb, pin Thunderbird tránh snap"
ok "DRAFT: Hoàn tất draft-del-snap-n-replace-apps.sh"

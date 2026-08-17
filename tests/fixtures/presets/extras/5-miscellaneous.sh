#!/bin/sh
# @setup-description: Preset Miscellaneous
# @setup-when: always
# @setup-item: flameshot|Flameshot
# @setup-item: warp|Cloudflare WARP
printf '%s|%s\n' "$(basename "$0")" "$*" >> "$SETUP_TEST_LOG"

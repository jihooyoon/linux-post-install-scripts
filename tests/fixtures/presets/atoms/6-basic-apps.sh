#!/bin/sh
# @setup-description: Preset Basic Apps
# @setup-when: always
# @setup-item: chrome|Chrome
# @setup-item: chromium|Chromium
# @setup-item: vscode|VS Code
printf '%s|%s\n' "$(basename "$0")" "$*" >> "$SETUP_TEST_LOG"

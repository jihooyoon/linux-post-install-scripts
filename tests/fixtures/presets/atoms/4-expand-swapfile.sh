#!/bin/sh
# @setup-description: Preset expand swapfile
# @setup-when: always
# @setup-core-description: expand swapfile
printf '%s|%s\n' "$(basename "$0")" "$*" >> "$SETUP_TEST_LOG"

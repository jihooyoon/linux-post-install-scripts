#!/bin/sh
# @setup-description: Preset Dev
# @setup-when: always
# @setup-core-description: core
printf '%s|%s\n' "$(basename "$0")" "$*" >> "$SETUP_TEST_LOG"

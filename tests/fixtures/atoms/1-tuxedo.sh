#!/bin/sh
# @setup-description: Tuxedo variant
# @setup-when: tuxedo
# @setup-core-description: tuxedo core
printf '%s|%s\n' "$(basename -- "$0")" "$*" >> "$SETUP_TEST_LOG"

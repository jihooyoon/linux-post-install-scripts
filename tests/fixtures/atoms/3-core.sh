#!/bin/sh
# @setup-description: Basic core fixture
# @setup-when: always
# @setup-core-description: atom core
printf '%s|%s\n' "$(basename -- "$0")" "$*" >> "$SETUP_TEST_LOG"

#!/bin/sh
# @setup-description: Atom items fixture
# @setup-when: always
# @setup-core-description: atom item fixture core
# @setup-item: first_item|First atom item
# @setup-item: second_item|Second atom item
printf '%s|%s\n' "$(basename -- "$0")" "$*" >> "$SETUP_TEST_LOG"

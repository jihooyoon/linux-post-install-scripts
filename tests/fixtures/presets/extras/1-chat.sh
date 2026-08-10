#!/bin/sh
# @setup-description: Preset Chat
# @setup-when: always
# @setup-item: slack|Slack
# @setup-item: mattermost|Mattermost
# @setup-item: discord|Discord
printf '%s|%s\n' "$(basename "$0")" "$*" >> "$SETUP_TEST_LOG"

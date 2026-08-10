#!/bin/sh
# @setup-description: Preset AI
# @setup-when: always
# @setup-item: claude_desktop|Claude Desktop
# @setup-item: claude_cli|Claude CLI
# @setup-item: codex_cli|Codex CLI
printf '%s|%s\n' "$(basename "$0")" "$*" >> "$SETUP_TEST_LOG"

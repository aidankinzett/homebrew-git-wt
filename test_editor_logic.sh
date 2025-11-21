#!/bin/bash
source lib/colors.sh
source lib/editor.sh

# Mock git config
function git() {
    if [[ "$1" == "config" && "$2" == "--get" && "$3" == "worktree.editor" ]]; then
        echo "$MOCK_GIT_EDITOR"
    else
        command git "$@"
    fi
}

# Mock commands
function command() {
    if [[ "$1" == "-v" ]]; then
        if [[ "$2" == "cursor" && "$MOCK_CURSOR_INSTALLED" == "true" ]]; then return 0; fi
        if [[ "$2" == "code" && "$MOCK_CODE_INSTALLED" == "true" ]]; then return 0; fi
        if [[ "$2" == "agy" && "$MOCK_AGY_INSTALLED" == "true" ]]; then return 0; fi
        return 1
    else
        builtin command "$@"
    fi
}

echo "--- Test 1: No config, only Cursor installed ---"
MOCK_GIT_EDITOR=""
MOCK_CURSOR_INSTALLED="true"
MOCK_CODE_INSTALLED="false"
MOCK_AGY_INSTALLED="false"
get_editor

echo "--- Test 2: No config, only Code installed ---"
MOCK_GIT_EDITOR=""
MOCK_CURSOR_INSTALLED="false"
MOCK_CODE_INSTALLED="true"
MOCK_AGY_INSTALLED="false"
get_editor

echo "--- Test 3: Configured code, code installed ---"
MOCK_GIT_EDITOR="code"
MOCK_CURSOR_INSTALLED="true"
MOCK_CODE_INSTALLED="true"
MOCK_AGY_INSTALLED="false"
get_editor

echo "--- Test 4: Configured agy, agy installed ---"
MOCK_GIT_EDITOR="agy"
MOCK_CURSOR_INSTALLED="true"
MOCK_CODE_INSTALLED="true"
MOCK_AGY_INSTALLED="true"
get_editor

echo "--- Test 5: Configured invalid editor ---"
MOCK_GIT_EDITOR="vim"
MOCK_CURSOR_INSTALLED="true"
get_editor 2>&1

echo "--- Test 6: Configured code, code NOT installed ---"
MOCK_GIT_EDITOR="code"
MOCK_CODE_INSTALLED="false"
MOCK_CURSOR_INSTALLED="true"
get_editor 2>&1

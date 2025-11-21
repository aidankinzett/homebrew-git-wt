#!/usr/bin/env bats

load 'test_helper/bats-support/load'
load 'test_helper/bats-assert/load'

setup() {
    # Create mock environment
    export TEST_DIR="$BATS_TMPDIR/git-wt-test-editor-$$"
    mkdir -p "$TEST_DIR"

    # Mock config/colors/logging
    source lib/colors.sh
    source lib/editor.sh

    # Mock info/blue/nc/git
    info() { echo "INFO: $*"; }
    BLUE=""
    NC=""

    # Mock git config
    git() {
        if [[ "$1" == "config" ]]; then
            if [[ "$2" == "--get" ]] && [[ "$3" == "worktree.editor" ]]; then
                echo "$MOCK_GIT_CONFIG_EDITOR"
            else
                echo ""
            fi
        else
             command git "$@"
        fi
    }
    export -f git

    # Mock command check
    # Note: in lib/editor.sh, $editor is executed directly, NOT via command.
    # So we need to mock 'mock_editor' etc as functions or executables.
    # But get_editor uses command -v check.

    command() {
        if [[ "$1" == "-v" ]]; then
            if [[ "$2" == "code" ]]; then
                [[ "$MOCK_CODE_INSTALLED" == "true" ]] && return 0 || return 1
            elif [[ "$2" == "cursor" ]]; then
                [[ "$MOCK_CURSOR_INSTALLED" == "true" ]] && return 0 || return 1
            else
                return 1
            fi
        else
             builtin command "$@"
        fi
    }
    export -f command

    mock_editor() {
         echo "Launched mock_editor with $1"
    }
    export -f mock_editor

    code() {
        echo "Launched code with $1"
    }
    export -f code

    cursor() {
        echo "Launched cursor with $1"
    }
    export -f cursor
}

teardown() {
    rm -rf "$TEST_DIR"
    unset GIT_WT_EDITOR_OVERRIDE
    unset VISUAL
    unset EDITOR
    unset MOCK_GIT_CONFIG_EDITOR
    unset MOCK_CODE_INSTALLED
    unset MOCK_CURSOR_INSTALLED
}

@test "get_editor: Override flag takes precedence" {
    export GIT_WT_EDITOR_OVERRIDE="mock_editor"
    export MOCK_GIT_CONFIG_EDITOR="other_editor"

    run get_editor
    assert_output "mock_editor"
}

@test "get_editor: git config takes precedence over env" {
    export MOCK_GIT_CONFIG_EDITOR="mock_editor"
    export VISUAL="visual_editor"
    export EDITOR="editor_editor"

    run get_editor
    assert_output "mock_editor"
}

@test "get_editor: VISUAL takes precedence over EDITOR" {
    export VISUAL="visual_editor"
    export EDITOR="editor_editor"

    run get_editor
    assert_output "visual_editor"
}

@test "get_editor: EDITOR takes precedence over defaults" {
    export EDITOR="editor_editor"
    export MOCK_CODE_INSTALLED="true"

    run get_editor
    assert_output "editor_editor"
}

@test "get_editor: defaults to code if installed" {
    export MOCK_CODE_INSTALLED="true"
    export MOCK_CURSOR_INSTALLED="true"

    run get_editor
    assert_output "code"
}

@test "get_editor: defaults to cursor if code not installed" {
    export MOCK_CODE_INSTALLED="false"
    export MOCK_CURSOR_INSTALLED="true"

    run get_editor
    assert_output "cursor"
}

@test "get_editor: returns failure if nothing found" {
    export MOCK_CODE_INSTALLED="false"
    export MOCK_CURSOR_INSTALLED="false"

    run get_editor
    assert_failure
}

@test "open_in_editor: launches editor if found" {
    export GIT_WT_EDITOR_OVERRIDE="mock_editor"

    run open_in_editor "/path/to/worktree"
    assert_output --partial "INFO: Opening worktree in mock_editor..."
    assert_output --partial "Launched mock_editor with /path/to/worktree"
}

@test "open_in_editor: shows cd instructions if no editor found" {
    export MOCK_CODE_INSTALLED="false"
    export MOCK_CURSOR_INSTALLED="false"

    run open_in_editor "/path/to/worktree"
    assert_output --partial "To switch to the new worktree, run:"
    assert_output --partial "cd /path/to/worktree"
}

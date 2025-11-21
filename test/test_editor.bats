#!/usr/bin/env bats

# shellcheck disable=SC2030,SC2031
# SC2030/SC2031: Variables modified in subshells (bats tests) are not visible in parent shells.
# We export variables for mocks, so this warning is expected behavior in bats tests.

# shellcheck disable=SC1091
load 'test_helper/bats-support/load'
# shellcheck disable=SC1091
load 'test_helper/bats-assert/load'

setup() {
    # Create mock environment
    export TEST_DIR="$BATS_TMPDIR/git-wt-test-editor-$$"
    mkdir -p "$TEST_DIR"

    # Mock config/colors/logging
    # shellcheck disable=SC1091
    source lib/colors.sh
    # shellcheck disable=SC1091
    source lib/editor.sh

    # Mock info/blue/nc/git
    # shellcheck disable=SC2317
    info() { echo "INFO: $*"; }
    # shellcheck disable=SC2317
    warning() { echo "WARNING: $*"; }
    # shellcheck disable=SC2034
    BLUE=""
    # shellcheck disable=SC2034
    NC=""

    # Mock git config
    # shellcheck disable=SC2317
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
    # shellcheck disable=SC2317
    command() {
        if [[ "$1" == "-v" ]]; then
            local cmd="$2"
            if [[ "$cmd" == "code" ]]; then
                [[ "$MOCK_CODE_INSTALLED" == "true" ]] && return 0 || return 1
            elif [[ "$cmd" == "cursor" ]]; then
                [[ "$MOCK_CURSOR_INSTALLED" == "true" ]] && return 0 || return 1
            elif [[ "$cmd" == "vim" ]]; then
                 # Always pretend vim is installed for tests
                 return 0
            elif [[ "$cmd" == "unknown_editor" ]]; then
                 return 0 # Pretend it exists but not allowed
            elif [[ "$cmd" == "mock_editor" ]]; then
                 return 0 # Pretend it exists but not allowed
            else
                # Default failure for others
                return 1
            fi
        else
             builtin command "$@"
        fi
    }
    export -f command

    # Mock editors
    # shellcheck disable=SC2317
    code() { echo "Launched code with $*"; }
    # shellcheck disable=SC2317
    cursor() { echo "Launched cursor with $*"; }
    # shellcheck disable=SC2317
    vim() { echo "Launched vim with $*"; }

    export -f code cursor vim
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
    export GIT_WT_EDITOR_OVERRIDE="vim"
    export MOCK_GIT_CONFIG_EDITOR="code"

    run get_editor
    assert_output "vim"
}

@test "get_editor: git config takes precedence over env" {
    export MOCK_GIT_CONFIG_EDITOR="vim"
    export VISUAL="code"
    export EDITOR="code"

    run get_editor
    assert_output "vim"
}

@test "get_editor: VISUAL takes precedence over EDITOR" {
    export VISUAL="vim"
    export EDITOR="code"

    run get_editor
    assert_output "vim"
}

@test "get_editor: EDITOR takes precedence over defaults" {
    export EDITOR="vim"
    export MOCK_CODE_INSTALLED="true"

    run get_editor
    assert_output "vim"
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

@test "open_in_editor: launches allowed editor (vim)" {
    export GIT_WT_EDITOR_OVERRIDE="vim"

    run open_in_editor "/path/to/worktree"
    assert_output --partial "INFO: Opening worktree in vim..."
    assert_output --partial "Launched vim with /path/to/worktree"
}

@test "open_in_editor: blocks unknown editor" {
    export GIT_WT_EDITOR_OVERRIDE="unknown_editor"

    run open_in_editor "/path/to/worktree"
    assert_output --partial "WARNING: Editor 'unknown_editor' is not in the allowlist"
    assert_output --partial "To switch to the new worktree, run:"
    assert_output --partial "cd /path/to/worktree"

    # Manual refute_output
    if [[ "$output" == *"Launched unknown_editor"* ]]; then
        echo "FAILURE: Launched unknown_editor despite block"
        exit 1
    fi
}

@test "open_in_editor: shows cd instructions if no editor found" {
    export MOCK_CODE_INSTALLED="false"
    export MOCK_CURSOR_INSTALLED="false"

    run open_in_editor "/path/to/worktree"
    assert_output --partial "To switch to the new worktree, run:"
    assert_output --partial "cd /path/to/worktree"
}

@test "open_in_editor: handles allowed editor with arguments" {
    export GIT_WT_EDITOR_OVERRIDE="vim -n"

    run open_in_editor "/path/to/worktree"
    assert_output --partial "INFO: Opening worktree in vim -n..."
    assert_output --partial "Launched vim with -n /path/to/worktree"
}

@test "open_in_editor: prevents command injection" {
    # Try to inject a command that creates a file
    local injection_file="$TEST_DIR/injected"

    export GIT_WT_EDITOR_OVERRIDE="vim; touch $injection_file"

    run open_in_editor "/path/to/worktree"

    # "vim;" is not in allowlist
    assert_output --partial "WARNING: Editor 'vim;' is not in the allowlist"

    # Verify the file was NOT created
    if [[ -f "$injection_file" ]]; then
        echo "FAILURE: Injection successful, file created: $injection_file"
        exit 1
    fi
}

#!/usr/bin/env bats

# Tests for UI functions in lib/ui.sh
# shellcheck disable=SC1091

load test_helper

setup() {
    setup_test_git_repo
    load_git_wt

    # Source the UI library
    source "$BATS_TEST_DIRNAME/../lib/colors.sh"
    source "$BATS_TEST_DIRNAME/../lib/ui.sh"
}

teardown() {
    teardown_test_git_repo
}

@test "ask_yes_no returns 0 for 'Yes'" {
    # Mock fzf to return 'Yes'
    # shellcheck disable=SC2317
    fzf() { echo "Yes"; }

    run ask_yes_no "Test prompt"
    [ "$status" -eq 0 ]
}

@test "ask_yes_no returns 1 for 'No'" {
    # Mock fzf to return 'No'
    # shellcheck disable=SC2317
    fzf() { echo "No"; }

    run ask_yes_no "Test prompt"
    [ "$status" -eq 1 ]
}

@test "ask_yes_no returns 1 on interruption" {
    # Mock fzf to simulate Ctrl-C
    # shellcheck disable=SC2317
    fzf() { return 130; }

    run ask_yes_no "Test prompt"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Prompt cancelled."* ]]
}

@test "show_loading prints message in non-interactive mode" {
    # Redirect stdout to a file to check output
    local tmpfile
    tmpfile=$(mktemp)

    # Run in a subshell to avoid affecting the test runner's terminal state
    (
        # Unset the interactive terminal flag
        exec > "$tmpfile"
        show_loading "Test message"
    )

    [ -s "$tmpfile" ]
    [[ $(cat "$tmpfile") == "Test message" ]]
    rm -f "$tmpfile"
}

@test "hide_loading does not fail without a pid" {
    run hide_loading ""
    [ "$status" -eq 0 ]
}

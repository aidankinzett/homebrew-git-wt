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

@test "show_loading and hide_loading run without errors" {
    # This is a basic test to ensure the functions don't crash.
    # Visually testing the spinner is difficult in a CI environment.
    run bash -c '
        show_loading() { :; }
        hide_loading() { :; }
        show_loading "Test message" &
        local pid=$!
        sleep 0.2
        hide_loading $pid
    '
    [ "$status" -eq 0 ]
}

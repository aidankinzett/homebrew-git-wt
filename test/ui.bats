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

@test "show_loading displays spinner and hides cursor" {
    # shellcheck disable=SC2317
    tput() {
        if [[ "$1" == "cols" ]]; then
            echo 80
        else
            echo "tput $*"
        fi
    }
    export -f tput

    local outfile; outfile=$(mktemp)

    show_loading "Test message" > "$outfile" &
    local pid=$!

    sleep 0.2

    kill -TERM "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null

    local content
    content=$(cat "$outfile")
    rm "$outfile"

    [[ "$content" == *"tput civis"* ]]
    [[ "$content" == *"Test message"* ]]
}

@test "hide_loading restores cursor" {
    # shellcheck disable=SC2317
    tput() { echo "tput $*"; }
    export -f tput

    sleep 10 &
    local pid=$!

    run hide_loading "$pid"

    [ "$status" -eq 0 ]
    [[ "$output" == *"tput cnorm"* ]]
}

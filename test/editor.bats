#!/usr/bin/env bats
# shellcheck disable=SC2317  # Ignore unreachable code warnings for mock functions

# Tests for editor logic

load test_helper

setup() {
    # Source the library
    # shellcheck source=/dev/null
    source lib/colors.sh
    # shellcheck source=/dev/null
    source lib/editor.sh
}

# Helper for asserting output contains string
assert_output() {
    local expected="$1"
    if [[ "$output" != *"$expected"* ]]; then
        echo "Expected output to contain: $expected"
        echo "Actual output: $output"
        return 1
    fi
}

# Helper for asserting output equals string
assert_equal() {
    local expected="$1"
    if [[ "$output" != "$expected" ]]; then
        echo "Expected: $expected"
        echo "Actual:   $output"
        return 1
    fi
}

@test "get_editor returns configured editor if valid and installed" {
    # Mock git config
    function git() {
        if [[ "$1" == "config" && "$2" == "--get" && "$3" == "worktree.editor" ]]; then
            echo "code"
        fi
    }
    export -f git

    # Mock command
    function command() {
        if [[ "$1" == "-v" ]]; then
            if [[ "$2" == "code" ]]; then return 0; fi
        fi
        return 1
    }
    export -f command

    run get_editor
    [ "$status" -eq 0 ]
    assert_equal "code"
}

@test "get_editor warns and falls back if configured editor is invalid" {
    # Mock git config
    function git() {
        if [[ "$1" == "config" && "$2" == "--get" && "$3" == "worktree.editor" ]]; then
            echo "vim"
        fi
    }
    export -f git

    # Mock command for fallback (cursor)
    function command() {
        if [[ "$1" == "-v" ]]; then
            if [[ "$2" == "cursor" ]]; then return 0; fi
        fi
        return 1
    }
    export -f command

    run get_editor

    # Verify status success (it falls back, doesn't fail)
    [ "$status" -eq 0 ]

    # Verify warning was printed
    assert_output "Invalid editor configured: vim"

    # Verify fallback value is the last line
    [[ "${lines[${#lines[@]}-1]}" == "cursor" ]]
}

@test "get_editor warns and falls back if configured editor is not installed" {
    # Mock git config
    function git() {
        if [[ "$1" == "config" && "$2" == "--get" && "$3" == "worktree.editor" ]]; then
            echo "code"
        fi
    }
    export -f git

    # Mock command - code not installed, cursor installed
    function command() {
        if [[ "$1" == "-v" ]]; then
            if [[ "$2" == "cursor" ]]; then return 0; fi
            if [[ "$2" == "code" ]]; then return 1; fi
        fi
        return 1
    }
    export -f command

    run get_editor

    # Verify status success
    [ "$status" -eq 0 ]

    # Verify warning
    assert_output "Configured editor 'code' not found in PATH"

    # Verify fallback value is the last line
    [[ "${lines[${#lines[@]}-1]}" == "cursor" ]]
}

@test "get_editor falls back to detected editor (cursor priority)" {
    # Mock git config (empty)
    function git() { echo ""; }
    export -f git

    # Mock command - all installed
    function command() {
        if [[ "$1" == "-v" ]]; then
            return 0
        fi
        return 1
    }
    export -f command

    run get_editor
    assert_equal "cursor"
}

@test "get_editor falls back to detected editor (code if cursor missing)" {
    # Mock git config (empty)
    function git() { echo ""; }
    export -f git

    # Mock command - cursor missing, code installed
    function command() {
        if [[ "$1" == "-v" ]]; then
            if [[ "$2" == "cursor" ]]; then return 1; fi
            if [[ "$2" == "code" ]]; then return 0; fi
        fi
        return 1
    }
    export -f command

    run get_editor
    assert_equal "code"
}

@test "get_editor returns error if no editor found" {
    # Mock git config (empty)
    function git() { echo ""; }
    export -f git

    # Mock command - none installed
    function command() { return 1; }
    export -f command

    run get_editor
    [ "$status" -ne 0 ]
}

@test "open_in_editor runs the editor command" {
    # Mock get_editor
    function get_editor() { echo "my_editor"; }
    export -f get_editor

    # Mock editor command
    function my_editor() { echo "Opened $1"; }
    export -f my_editor

    # Mock info
    function info() { :; }
    export -f info

    run open_in_editor "/path/to/worktree"
    assert_equal "Opened /path/to/worktree"
}

@test "open_in_editor prints cd command if no editor found" {
    # Mock get_editor (fail)
    function get_editor() { return 1; }
    export -f get_editor

    # Mock info
    function info() { :; }
    export -f info

    run open_in_editor "/path/to/worktree"
    # We expect it to contain "cd /path/to/worktree" but with colors
    assert_output "cd /path/to/worktree"
}

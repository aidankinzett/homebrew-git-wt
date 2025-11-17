#!/usr/bin/env bats

# Tests for validate_worktree_path function

load test_helper

setup() {
    setup_test_git_repo
    load_git_wt
}

teardown() {
    teardown_test_git_repo
}

last_line() {
    echo "${lines[${#lines[@]}-1]}"
}

@test "validate_worktree_path expands tilde to home directory" {
    # shellcheck disable=SC2088  # Provide literal tilde to test expansion
    run validate_worktree_path "~/test/path" "test source"

    [ "$status" -eq 0 ]
    # Path will be canonicalized by validate_worktree_path
    expected=$(canonicalize_path "$HOME/test/path")
    [ "$(last_line)" = "$expected" ]
}

@test "validate_worktree_path rejects paths with semicolon" {
    run validate_worktree_path "/tmp/test;rm" "test source"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"contains dangerous characters"* ]]
}

@test "validate_worktree_path rejects paths with pipe" {
    run validate_worktree_path "/tmp/test|rm" "test source"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"contains dangerous characters"* ]]
}

@test "validate_worktree_path rejects paths with ampersand" {
    run validate_worktree_path "/tmp/test&rm" "test source"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"contains dangerous characters"* ]]
}

@test "validate_worktree_path rejects paths with dollar sign" {
    run validate_worktree_path "/tmp/test\$rm" "test source"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"contains dangerous characters"* ]]
}

@test "validate_worktree_path rejects paths with backtick" {
    run validate_worktree_path "/tmp/test\`rm" "test source"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"contains dangerous characters"* ]]
}

@test "validate_worktree_path rejects relative paths" {
    run validate_worktree_path "test/path" "test source"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"must be an absolute path"* ]]
}

@test "validate_worktree_path accepts valid absolute paths" {
    local path="$TEST_TEMP_DIR/absolute/test/path"
    run validate_worktree_path "$path" "test source"

    [ "$status" -eq 0 ]
    # Path will be canonicalized
    expected=$(canonicalize_path "$path")
    [ "$(last_line)" = "$expected" ]
}

@test "validate_worktree_path removes trailing slashes" {
    local path="$TEST_TEMP_DIR/trailing/test/path"
    run validate_worktree_path "${path}/" "test source"

    [ "$status" -eq 0 ]
    # Path will be canonicalized (trai ling slash removed and symlinks resolved)
    expected=$(canonicalize_path "$path")
    [ "$(last_line)" = "$expected" ]
}

@test "validate_worktree_path canonicalizes paths with realpath when available" {
    if command -v realpath &> /dev/null; then
        local base="$TEST_TEMP_DIR/canonical"
        mkdir -p "$base"
        run validate_worktree_path "$base/../canonical/test" "test source"
        
        [ "$status" -eq 0 ]
        # Should resolve to "$TEST_TEMP_DIR/canonical/test" (or /private/tmp/canonical/test on macOS)
        [[ "$(last_line)" == *"/canonical/test" ]]
    else
        skip "realpath not available"
    fi
}

@test "validate_worktree_path includes source in error messages" {
    run validate_worktree_path "relative/path" "local git config"
    
    [ "$status" -eq 1 ]
    [[ "$output" == *"local git config"* ]]
}


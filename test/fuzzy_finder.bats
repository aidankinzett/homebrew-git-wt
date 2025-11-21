#!/usr/bin/env bats

# Tests for fuzzy finder delete and recreate functionality
# shellcheck disable=SC1091

load test_helper

setup() {
    setup_test_git_repo
    load_git_wt

    # Set up a project name for testing
    git remote add origin https://github.com/testuser/test-repo.git

    # Set up worktree base
    WORKTREE_BASE="$TEST_TEMP_DIR/worktrees"
    export WORKTREE_BASE

    # Source library files
    source "$BATS_TEST_DIRNAME/../lib/colors.sh"
    source "$BATS_TEST_DIRNAME/../lib/validation.sh"
    source "$BATS_TEST_DIRNAME/../lib/config.sh"
    source "$BATS_TEST_DIRNAME/../lib/git-utils.sh"
    source "$BATS_TEST_DIRNAME/../lib/package-manager.sh"
    source "$BATS_TEST_DIRNAME/../lib/worktree-ops.sh"
    source "$BATS_TEST_DIRNAME/../lib/ui.sh"
    source "$BATS_TEST_DIRNAME/../lib/fuzzy-finder.sh"
    source "$BATS_TEST_DIRNAME/../lib/commands.sh"

    # Create a test branch
    git checkout -b test-branch
    echo "test content" > test.txt
    git add test.txt
    git commit -m "Test commit"
    git checkout main 2>/dev/null || git checkout master
}

teardown() {
    teardown_test_git_repo
}

@test "delete_worktree_with_check deletes clean worktree" {
    # Create a worktree
    local branch="feature/delete-clean"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"
    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"
    [ -d "$worktree_path" ]

    # Mock UI functions to avoid interactive prompts in tests
    # shellcheck disable=SC2317
    show_loading() { :; }
    # shellcheck disable=SC2317
    hide_loading() { :; }

    run delete_worktree_with_check "feature/delete-clean"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Worktree for 'feature/delete-clean' deleted."* ]]
    [ ! -d "$worktree_path" ]
}

@test "delete_worktree_with_check handles non-existent worktree" {
    run delete_worktree_with_check "feature/non-existent"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Worktree for 'feature/non-existent' does not exist."* ]]
}

@test "delete_worktree_with_check prompts to force delete a dirty worktree" {
    # Create a dirty worktree
    local branch="feature/delete-dirty"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"
    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"
    echo "dirty" > "$worktree_path/dirty.txt"

    # Mock UI functions
    # shellcheck disable=SC2317
    ask_yes_no() { return 0; }
    # shellcheck disable=SC2317
    show_loading() { :; }
    # shellcheck disable=SC2317
    hide_loading() { :; }

    run delete_worktree_with_check "feature/delete-dirty"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Failed to delete worktree"* ]]
    [[ "$output" == *"Worktree force-deleted successfully."* ]]
    [ ! -d "$worktree_path" ]
}

@test "delete_worktree_with_check cancels on no to force delete" {
    # Create a dirty worktree
    local branch="feature/delete-dirty"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"
    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"
    echo "dirty" > "$worktree_path/dirty.txt"

    # Mock UI functions
    # shellcheck disable=SC2317
    ask_yes_no() { return 1; }
    # shellcheck disable=SC2317
    show_loading() { :; }
    # shellcheck disable=SC2317
    hide_loading() { :; }

    run delete_worktree_with_check "feature/delete-dirty"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Deletion cancelled."* ]]
    [ -d "$worktree_path" ]
}

@test "recreate_worktree recreates a clean worktree" {
    # Create a worktree
    local branch="feature/recreate-clean"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"
    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"
    [ -d "$worktree_path" ]

    # Mock UI and cmd_add
    # shellcheck disable=SC2317
    show_loading() { :; }
    # shellcheck disable=SC2317
    hide_loading() { :; }
    # shellcheck disable=SC2317
    cmd_add() { echo "mock cmd_add called for $1"; }

    run recreate_worktree "feature/recreate-clean"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Old worktree removed."* ]]
    [[ "$output" == *"mock cmd_add called for feature/recreate-clean"* ]]
}

@test "recreate_worktree prompts to force recreate a dirty worktree" {
    # Create a dirty worktree
    local branch="feature/recreate-dirty"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"
    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"
    echo "dirty" > "$worktree_path/dirty.txt"

    # Mock UI and cmd_add
    # shellcheck disable=SC2317
    ask_yes_no() { return 0; }
    # shellcheck disable=SC2317
    show_loading() { :; }
    # shellcheck disable=SC2317
    hide_loading() { :; }
    # shellcheck disable=SC2317
    cmd_add() { echo "mock cmd_add called for $1"; }

    run recreate_worktree "feature/recreate-dirty"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Failed to delete worktree"* ]]
    [[ "$output" == *"Old worktree removed."* ]]
    [[ "$output" == *"mock cmd_add called for feature/recreate-dirty"* ]]
}

@test "recreate_worktree cancels on no to force recreate" {
    # Create a dirty worktree
    local branch="feature/recreate-dirty"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"
    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"
    echo "dirty" > "$worktree_path/dirty.txt"

    # Mock UI and cmd_add
    # shellcheck disable=SC2317
    ask_yes_no() { return 1; }
    # shellcheck disable=SC2317
    show_loading() { :; }
    # shellcheck disable=SC2317
    hide_loading() { :; }
    # shellcheck disable=SC2317
    cmd_add() { echo "mock cmd_add called for $1"; }

    run recreate_worktree "feature/recreate-dirty"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Recreation cancelled."* ]]
    [ -d "$worktree_path" ]
}

@test "recreate_worktree fails when worktree doesn't exist" {
    run recreate_worktree "nonexistent-branch"

    [ "$status" -eq 1 ]
    [[ "$output" == *"Worktree for 'nonexistent-branch' does not exist."* ]]
}

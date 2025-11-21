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

@test "_delete_worktree_internal returns correct exit codes" {
    # Create a worktree
    local branch="feature/internal-delete"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"
    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"
    [ -d "$worktree_path" ]

    # Mock UI functions
    # shellcheck disable=SC2317
    show_loading() { echo "12345 /tmp/dummyflag"; }
    # shellcheck disable=SC2317
    hide_loading() { :; }
    # shellcheck disable=SC2317
    ask_yes_no() { return 2; } # Cancel

    run _delete_worktree_internal "$branch" "$worktree_path" "Force delete?"
    [ "$status" -eq 2 ]
}

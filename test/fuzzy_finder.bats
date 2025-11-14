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

@test "delete_worktree_interactive deletes clean worktree successfully" {
    # Create a worktree
    local branch="feature/test"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"

    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"

    # Verify worktree exists
    [ -d "$worktree_path" ]

    # Delete worktree (simulate fzf line with branch name)
    run delete_worktree_interactive "  feature/test"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted worktree"* ]]
    [ ! -d "$worktree_path" ]
}

@test "delete_worktree_interactive handles worktree with ANSI codes" {
    # Create a worktree
    local branch="feature/ansi"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"

    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"

    # Verify worktree exists
    [ -d "$worktree_path" ]

    # Delete worktree with ANSI codes (like fzf would provide)
    local ansi_line=$'\033[0;32m✓\033[0m feature/ansi'
    run delete_worktree_interactive "$ansi_line"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted worktree"* ]]
    [ ! -d "$worktree_path" ]
}

@test "delete_worktree_interactive fails when worktree doesn't exist" {
    # Try to delete non-existent worktree
    run delete_worktree_interactive "nonexistent-branch"

    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "delete_worktree_interactive cleans up empty parent directories" {
    # Create a worktree
    local branch="feature/cleanup"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"
    local parent_dir
    parent_dir="$(dirname "$worktree_path")"

    mkdir -p "$parent_dir"
    git worktree add "$worktree_path" -b "$branch"

    # Verify parent exists
    [ -d "$parent_dir" ]

    # Delete worktree
    run delete_worktree_interactive "feature/cleanup"

    [ "$status" -eq 0 ]
    # Parent should be removed (it's empty after deletion)
    [ ! -d "$parent_dir" ]
}

@test "delete_worktree_interactive prompts for confirmation with uncommitted changes" {
    # Create a worktree
    local branch="feature/dirty"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"

    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"

    # Add uncommitted changes
    echo "dirty content" > "$worktree_path/dirty.txt"

    # Try to delete (simulate 'N' response)
    run delete_worktree_interactive 'feature/dirty' <<< 'N'

    [ "$status" -eq 1 ]
    [[ "$output" == *"uncommitted changes"* ]]
    [[ "$output" == *"Deletion cancelled"* ]]
    [ -d "$worktree_path" ]
}

@test "delete_worktree_interactive deletes dirty worktree with confirmation" {
    # Create a worktree
    local branch="feature/force-delete"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"

    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"

    # Add uncommitted changes
    echo "dirty content" > "$worktree_path/dirty.txt"

    # Delete with 'y' response
    run delete_worktree_interactive 'feature/force-delete' <<< 'y'

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted worktree"* ]]
    [ ! -d "$worktree_path" ]
}

@test "recreate_worktree recreates clean worktree successfully" {
    skip "Recreate requires full cmd_add setup with package manager detection"

    # Create a worktree
    local branch="feature/recreate"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"

    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"

    # Add a marker file
    echo "original" > "$worktree_path/marker.txt"

    # Recreate worktree
    run recreate_worktree "feature/recreate"

    [ "$status" -eq 0 ]
    [[ "$output" == *"Deleted old worktree"* ]]
    [[ "$output" == *"Creating fresh worktree"* ]]
    [ -d "$worktree_path" ]
    # Marker file should not exist (fresh worktree)
    [ ! -f "$worktree_path/marker.txt" ]
}

@test "recreate_worktree fails when worktree doesn't exist" {
    # Try to recreate non-existent worktree
    run recreate_worktree "nonexistent-branch"

    [ "$status" -eq 1 ]
    [[ "$output" == *"does not exist"* ]]
}

@test "recreate_worktree prompts for confirmation with uncommitted changes" {
    skip "Recreate requires full cmd_add setup with package manager detection"

    # Create a worktree
    local branch="feature/recreate-dirty"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"

    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"

    # Add uncommitted changes
    echo "dirty content" > "$worktree_path/dirty.txt"

    # Try to recreate (simulate 'N' response)
    run recreate_worktree 'feature/recreate-dirty' <<< 'N'

    [ "$status" -eq 1 ]
    [[ "$output" == *"uncommitted changes"* ]]
    [[ "$output" == *"Recreate cancelled"* ]]
    [ -d "$worktree_path" ]
}

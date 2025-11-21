#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_git_repo
    # Mock worktree base
    mkdir -p "$HOME/Git/.worktrees"
    export WORKTREE_BASE="$HOME/Git/.worktrees"
    export GIT_WT_BASE="$WORKTREE_BASE"

    # Source git-wt libraries
    load_git_wt
}

teardown() {
    teardown_test_git_repo
}

@test "cmd_list lists worktrees" {
    # Create a worktree
    git branch feature-1
    git worktree add "$TEST_TEMP_DIR/wt-1" feature-1

    run cmd_list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "feature-1" ]]
    # shellcheck disable=SC2076
    [[ "$output" =~ "$TEST_TEMP_DIR/wt-1" ]]
}

@test "cmd_remove removes existing worktree" {
    git branch feature-rem
    local project_name
    project_name=$(basename "$TEST_TEMP_DIR")
    local wt_path="$WORKTREE_BASE/$project_name/feature-rem"
    git worktree add "$wt_path" feature-rem

    run cmd_remove "feature-rem"
    [ "$status" -eq 0 ]
    [ ! -d "$wt_path" ]
}

@test "cmd_remove fails for non-existent worktree" {
    run cmd_remove "non-existent"
    [ "$status" -eq 1 ]
}

@test "cmd_remove cleans up empty parent directory" {
    git branch feature-nested
    mkdir -p "$WORKTREE_BASE/project/subdir"
    local wt_path="$WORKTREE_BASE/project/subdir/nested"
    git worktree add "$wt_path" feature-nested

    # We need to mock get_project_name to return "project/subdir" ??
    # cmd_remove uses get_project_name + branch name to calculate path.
    # worktree_path="$WORKTREE_BASE/$project_name/$branch_name"

    # So if we want to test cleanup, we should stick to the standard path structure.
    local project_name
    project_name=$(basename "$TEST_TEMP_DIR")
    # If we make branch name "subdir/nested", then parent dir "subdir" might be cleaned.

    git branch subdir/nested
    local wt_path="$WORKTREE_BASE/$project_name/subdir/nested"
    git worktree add "$wt_path" subdir/nested

    run cmd_remove "subdir/nested"
    [ "$status" -eq 0 ]
    [ ! -d "$wt_path" ]
    # Parent subdir should be removed if empty
    [ ! -d "$WORKTREE_BASE/$project_name/subdir" ]
}

@test "cmd_prune runs git worktree prune" {
    # Create a stale reference (manually remove worktree directory)
    git branch feature-prune
    local wt_path="$TEST_TEMP_DIR/wt-prune"
    git worktree add "$wt_path" feature-prune
    rm -rf "$wt_path"

    # Verify it shows as prunable
    run git worktree prune --dry-run
    [[ "$output" =~ "wt-prune" ]]

    run cmd_prune
    [ "$status" -eq 0 ]

    # Verify it's gone
    run git worktree list
    [[ ! "$output" =~ "wt-prune" ]]
}

@test "cmd_add requires branch name" {
    run cmd_add
    [ "$status" -eq 1 ]
    [[ "$output" =~ "Branch name is required" ]]
}

@test "cmd_add creates worktree for new branch" {
    local project_name
    project_name=$(basename "$TEST_TEMP_DIR")
    local branch="new-feature"
    local expected_path="$WORKTREE_BASE/$project_name/$branch"

    run cmd_add "$branch"
    [ "$status" -eq 0 ]
    [ -d "$expected_path" ]

    cd "$expected_path"
    current_branch=$(git branch --show-current)
    [ "$current_branch" = "$branch" ]
}

@test "cmd_add creates worktree for existing local branch" {
    local project_name
    project_name=$(basename "$TEST_TEMP_DIR")
    local branch="existing-local"
    git branch "$branch"

    local expected_path="$WORKTREE_BASE/$project_name/$branch"

    run cmd_add "$branch"
    [ "$status" -eq 0 ]
    [ -d "$expected_path" ]
}

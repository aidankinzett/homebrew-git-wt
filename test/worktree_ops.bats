#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_git_repo
    # Create a mock worktree base directory
    mkdir -p "$HOME/Git/.worktrees"
    export WORKTREE_BASE="$HOME/Git/.worktrees"
    export GIT_WT_BASE="$WORKTREE_BASE"

    load_git_wt
}

teardown() {
    teardown_test_git_repo
}

@test "has_worktree returns true for existing worktree in default location" {
    local project_name
    project_name=$(basename "$TEST_TEMP_DIR")

    mkdir -p "$WORKTREE_BASE/$project_name/feature-branch"

    run has_worktree "feature-branch"
    [ "$status" -eq 0 ]
}

@test "has_worktree returns true for registered worktree in custom location" {
    # Create a real worktree
    git branch feature-branch
    # Use directory name matching branch name because has_worktree enforces this
    git worktree add "$TEST_TEMP_DIR/feature-branch" feature-branch

    run has_worktree "feature-branch"
    [ "$status" -eq 0 ]
}

@test "has_worktree returns false for non-existent worktree" {
    run has_worktree "non-existent-branch"
    [ "$status" -eq 1 ]
}

@test "get_worktree_path returns path for registered worktree" {
    git branch feature-branch
    local wt_path="$TEST_TEMP_DIR/feature-branch"
    git worktree add "$wt_path" feature-branch

    run get_worktree_path "feature-branch"
    [ "$status" -eq 0 ]
    [ "$output" = "$wt_path" ]
}

@test "get_worktree_path returns expected path when not registered but expected" {
    local project_name
    project_name=$(basename "$TEST_TEMP_DIR")

    local expected_path="$WORKTREE_BASE/$project_name/future-branch"

    run get_worktree_path "future-branch"
    [ "$status" -eq 0 ]
    [ "$output" = "$expected_path" ]
}

@test "is_worktree_stale returns true for merged clean worktree" {
    # Create a worktree
    git branch feature-merged
    local wt_path="$TEST_TEMP_DIR/wt-merged"
    git worktree add "$wt_path" feature-merged

    # Make a commit on feature-merged
    cd "$wt_path"
    echo "change" > change.txt
    git add change.txt
    git commit -m "change"

    # Merge into main
    cd "$TEST_TEMP_DIR"
    git merge feature-merged

    # Now check if stale
    run is_worktree_stale "feature-merged" "$wt_path"
    [ "$status" -eq 0 ]
}

@test "is_worktree_stale returns false for unmerged worktree" {
    git branch feature-unmerged
    local wt_path="$TEST_TEMP_DIR/wt-unmerged"
    git worktree add "$wt_path" feature-unmerged

    cd "$wt_path"
    echo "change" > change.txt
    git add change.txt
    git commit -m "change"

    run is_worktree_stale "feature-unmerged" "$wt_path"
    [ "$status" -eq 1 ]
}

@test "is_worktree_stale returns false for dirty worktree" {
    git branch feature-dirty
    local wt_path="$TEST_TEMP_DIR/wt-dirty"
    git worktree add "$wt_path" feature-dirty

    # Merge it first so it would be stale if not dirty
    cd "$wt_path"
    echo "change" > change.txt
    git add change.txt
    git commit -m "change"

    cd "$TEST_TEMP_DIR"
    git merge feature-dirty

    # Now make it dirty
    cd "$wt_path"
    echo "dirty" > dirty.txt

    run is_worktree_stale "feature-dirty" "$wt_path"
    [ "$status" -eq 1 ]
}

@test "auto_prune_stale_worktrees prunes stale worktrees" {
    # Setup stale worktree
    git branch stale-branch
    local wt_path="$TEST_TEMP_DIR/stale-wt"
    git worktree add "$wt_path" stale-branch

    cd "$wt_path"
    echo "content" > file.txt
    git add file.txt
    git commit -m "content"

    cd "$TEST_TEMP_DIR"
    git merge stale-branch

    # Verify it exists
    [ -d "$wt_path" ]

    # Run auto prune
    run auto_prune_stale_worktrees

    # Verify it's gone
    [ ! -d "$wt_path" ]
    [[ "$output" =~ "Auto-pruned 1 merged worktree" ]]
}

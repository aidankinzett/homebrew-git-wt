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
    # Create a worktree in the standard location
    git branch feature-1
    local project_name
    project_name=$(basename "$TEST_TEMP_DIR")
    local wt_path="$WORKTREE_BASE/$project_name/feature-1"
    git worktree add "$wt_path" feature-1

    run cmd_list
    [ "$status" -eq 0 ]
    [[ "$output" =~ "feature-1" ]]
    # shellcheck disable=SC2076
    [[ "$output" =~ "$wt_path" ]]
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
    # Setup: Create a worktree with a nested branch name (e.g., feature/nested)
    # This creates a directory structure like .../feature/nested
    # When removed, the empty 'feature' directory should also be removed

    local project_name
    project_name=$(basename "$TEST_TEMP_DIR")

    git branch group/nested
    local wt_path="$WORKTREE_BASE/$project_name/group/nested"
    git worktree add "$wt_path" group/nested

    run cmd_remove "group/nested"
    [ "$status" -eq 0 ]

    # Verify worktree is gone
    [ ! -d "$wt_path" ]

    # Verify parent directory 'group' is also gone (cleanup)
    [ ! -d "$WORKTREE_BASE/$project_name/group" ]
}

@test "cmd_prune runs git worktree prune" {
    # Create a stale reference (manually remove worktree directory)
    git branch feature-prune
    local project_name
    project_name=$(basename "$TEST_TEMP_DIR")
    local wt_path="$WORKTREE_BASE/$project_name/feature-prune"
    git worktree add "$wt_path" feature-prune
    rm -rf "$wt_path"

    # Verify it shows as prunable
    run git worktree prune --dry-run
    [[ "$output" =~ "feature-prune" ]]

    run cmd_prune
    [ "$status" -eq 0 ]

    # Verify it's gone
    run git worktree list
    [[ ! "$output" =~ "feature-prune" ]]
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

@test "cmd_add creates worktree from remote branch" {
    # When a remote is configured, get_project_name uses the remote name
    local project_name="remote-repo"
    local branch="remote-feature"
    local expected_path="$WORKTREE_BASE/$project_name/$branch"

    # Setup a "remote" repo
    mkdir "$TEST_TEMP_DIR/remote-repo"
    (cd "$TEST_TEMP_DIR/remote-repo" && git init --bare --initial-branch=main)
    git remote add origin "$TEST_TEMP_DIR/remote-repo"

    # Push a branch to remote
    git branch "$branch"
    git push origin "$branch"
    # Delete local branch to ensure we are testing the remote tracking logic
    git branch -D "$branch"

    run cmd_add "$branch"
    if [ "$status" -ne 0 ]; then
        echo "Command output: $output" >&3
    fi
    [ "$status" -eq 0 ]
    [ -d "$expected_path" ]
    [[ "$output" =~ "Worktree created from remote branch" ]]

    # Verify tracking setup
    cd "$expected_path"
    current_branch=$(git branch --show-current)
    [ "$current_branch" = "$branch" ]

    # Check upstream
    upstream=$(git rev-parse --abbrev-ref --symbolic-full-name "@{u}" 2>/dev/null)
    [ "$upstream" = "origin/$branch" ]
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

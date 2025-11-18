#!/usr/bin/env bats

# Tests for cmd_refresh_env command

load test_helper

setup() {
    setup_test_git_repo
    load_git_wt

    # Create a worktree structure
    export WORKTREE_BASE="$TEST_TEMP_DIR/worktrees"
    mkdir -p "$WORKTREE_BASE"

    # Get project name
    PROJECT_NAME=$(get_project_name)
    export PROJECT_DIR="$WORKTREE_BASE/$PROJECT_NAME"
}

teardown() {
    teardown_test_git_repo
}

@test "cmd_refresh_env rejects too many arguments" {
    run cmd_refresh_env branch1 branch2

    [ "$status" -eq 1 ]
    [[ "$output" =~ "Too many arguments" ]]
    [[ "$output" =~ "Usage: git-wt --refresh-env" ]]
}

@test "cmd_refresh_env accepts zero arguments (refresh all)" {
    # Create a test worktree
    git worktree add "$PROJECT_DIR/test-branch" -b test-branch

    # Add env file to main worktree
    echo "TEST=true" > .env

    # Create initial symlink so there's something to refresh
    ln -s "$PWD/.env" "$PROJECT_DIR/test-branch/.env"

    run cmd_refresh_env

    # Should succeed or at least not error
    # Note: function might return 0 from refresh_env_symlinks return value
    [[ "$status" -eq 0 ]] || [[ "$output" =~ "Refreshed env symlinks" ]]
}

@test "cmd_refresh_env accepts one argument (specific branch)" {
    # Create a test worktree
    git worktree add "$PROJECT_DIR/test-branch" -b test-branch

    # Add env file to main worktree
    echo "TEST=true" > .env

    # Create initial symlink
    ln -s "$PWD/.env" "$PROJECT_DIR/test-branch/.env"

    run cmd_refresh_env test-branch

    [ "$status" -eq 0 ]
    [[ "$output" =~ "test-branch" ]]
}

@test "cmd_refresh_env fails for non-existent branch" {
    run cmd_refresh_env non-existent-branch

    [ "$status" -eq 1 ]
    [[ "$output" =~ "No worktree found for branch" ]]
}

@test "cmd_refresh_env refuses to refresh main worktree" {
    # Try to refresh main branch
    MAIN_BRANCH=$(git branch --show-current)

    run cmd_refresh_env "$MAIN_BRANCH"

    [ "$status" -eq 1 ]
    [[ "$output" =~ "Cannot refresh main worktree" ]]
}

@test "cmd_refresh_env handles worktree with detached HEAD" {
    # Create worktree with detached HEAD
    git worktree add --detach "$PROJECT_DIR/detached" HEAD

    # Add env file and create symlink
    echo "TEST=true" > .env
    ln -s "$PWD/.env" "$PROJECT_DIR/detached/.env"

    # This should work and display HEAD@commit
    run cmd_refresh_env

    # Should succeed and show detached HEAD format
    [ "$status" -eq 0 ]
    [[ "$output" =~ "HEAD@" ]]
}

@test "cmd_refresh_env refreshes all worktrees when no argument given" {
    # Create multiple worktrees
    git worktree add "$PROJECT_DIR/branch1" -b branch1
    git worktree add "$PROJECT_DIR/branch2" -b branch2

    # Add env file
    echo "TEST=true" > .env

    # Create initial symlinks
    ln -s "$PWD/.env" "$PROJECT_DIR/branch1/.env"
    ln -s "$PWD/.env" "$PROJECT_DIR/branch2/.env"

    run cmd_refresh_env

    [ "$status" -eq 0 ]
    [[ "$output" =~ "branch1" ]]
    [[ "$output" =~ "branch2" ]]
}

@test "cmd_refresh_env uses atomic symlink updates" {
    # Create a worktree
    git worktree add "$PROJECT_DIR/test-branch" -b test-branch

    # Add env files
    echo "OLD=true" > .env
    ln -s "$PWD/.env" "$PROJECT_DIR/test-branch/.env"

    # Change env file
    rm .env
    echo "NEW=true" > .env.local

    run cmd_refresh_env test-branch

    [ "$status" -eq 0 ]

    # Verify old symlink is gone
    [ ! -e "$PROJECT_DIR/test-branch/.env" ]

    # Verify new symlink exists
    [ -L "$PROJECT_DIR/test-branch/.env.local" ]

    # Verify no .tmp files left behind
    ! ls "$PROJECT_DIR/test-branch"/.env*.tmp.* 2>/dev/null
}

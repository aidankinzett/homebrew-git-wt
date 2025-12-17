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

    # Create a mock for bun
    # We put it in a directory that is in PATH
    mkdir -p "$TEST_TEMP_DIR/bin"
    export PATH="$TEST_TEMP_DIR/bin:$PATH"

    cat << 'EOF' > "$TEST_TEMP_DIR/bin/bun"
#!/bin/sh
echo "Mock bun called with: $*"
if [ "$1" = "install" ]; then
    echo "Dependencies installed successfully"
    exit 0
fi
exit 1
EOF
    chmod +x "$TEST_TEMP_DIR/bin/bun"
}

teardown() {
    teardown_test_git_repo
}

@test "cmd_add installs dependencies with bun when bun.lockb exists" {
    local project_name
    project_name=$(basename "$TEST_TEMP_DIR")
    local branch="bun-branch-bin"

    # Create a dummy bun.lockb in the main repo so it gets copied/checked
    # cmd_add creates a NEW worktree from the current state if branch doesn't exist.
    # So if we add bun.lockb to the current repo (main), and create a new branch from it, it will have the file.

    touch "bun.lockb"
    touch "package.json"
    git add .
    git commit -m "Add bun lockfile"

    run cmd_add "$branch"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Detected package manager: bun" ]]
    [[ "$output" =~ "Dependencies installed successfully" ]]
}

@test "cmd_add installs dependencies with bun when bun.lock exists" {
    local project_name
    project_name=$(basename "$TEST_TEMP_DIR")
    local branch="bun-branch-text"

    # Clean up previous lockfile if any
    rm -f bun.lockb

    touch "bun.lock"
    touch "package.json"
    git add .
    git commit -m "Add bun text lockfile"

    run cmd_add "$branch"

    [ "$status" -eq 0 ]
    [[ "$output" =~ "Detected package manager: bun" ]]
    [[ "$output" =~ "Dependencies installed successfully" ]]
}

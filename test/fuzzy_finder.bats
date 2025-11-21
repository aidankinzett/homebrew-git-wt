#!/usr/bin/env bats
# shellcheck disable=SC1091,SC2218

load test_helper

setup() {
    setup_test_git_repo
    load_git_wt
    git remote add origin https://github.com/testuser/test-repo.git
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

@test "delete_worktree_internal returns correct exit codes" {
    # Create a worktree
    local branch="feature/internal-delete"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"
    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"
    [ -d "$worktree_path" ]

    # Mock UI functions
    # shellcheck disable=SC2317
    show_loading() { :; }
    # shellcheck disable=SC2317
    hide_loading() { :; }
    # shellcheck disable=SC2317
    ask_yes_no() { return 2; } # Cancel

    # Mock git to simulate failure
    git() {
        if [[ "$1" == "worktree" && "$2" == "remove" ]]; then
            echo "fatal: contains modified or untracked files"
            return 1
        fi
        command git "$@"
    }

    run _delete_worktree_internal "$branch" "$worktree_path" "Force delete?"
    [ "$status" -eq 2 ]
}

@test "open_or_create_worktree calls open_in_editor for existing worktree" {
    local branch="feature/existing"
    local worktree_path="$WORKTREE_BASE/test-repo/$branch"
    mkdir -p "$(dirname "$worktree_path")"
    git worktree add "$worktree_path" -b "$branch"

    # Mock open_in_editor
    # shellcheck disable=SC2317
    open_in_editor() {
        echo "Called open_in_editor with $1"
    }
    export -f open_in_editor

    run open_or_create_worktree "  $branch"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Called open_in_editor with $worktree_path"* ]]
}

@test "open_or_create_worktree calls cmd_add for new worktree" {
    local branch="feature/new"

    # Mock cmd_add
    # shellcheck disable=SC2317
    cmd_add() {
        echo "Called cmd_add with $1"
    }
    export -f cmd_add

    run open_or_create_worktree "$branch"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Called cmd_add with $branch"* ]]
}

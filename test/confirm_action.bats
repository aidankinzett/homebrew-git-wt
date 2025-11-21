#!/usr/bin/env bats

load test_helper

setup() {
    setup_test_git_repo
    git remote add origin https://example.com/repo.git
    load_git_wt
    
    # Mock cursor to prevent opening editor
    # shellcheck disable=SC2317,SC2329
    function cursor() {
        return 0
    }
    export -f cursor
}

teardown() {
    teardown_test_git_repo
    rm -f "$FZF_OUTPUT_FILE" "$FZF_ARGS_FILE"
}

@test "confirm_action returns 0 when user selects Yes" {
    echo "Yes" > "$FZF_OUTPUT_FILE"
    
    run confirm_action "Title" "Message" "Action"
    
    [ "$status" -eq 0 ]
    # Verify fzf was called with correct header
    grep -q "Title" "$FZF_ARGS_FILE"
    grep -q "Message" "$FZF_ARGS_FILE"
    grep -q "Action" "$FZF_ARGS_FILE"
}

@test "confirm_action returns 1 when user selects No" {
    echo "No" > "$FZF_OUTPUT_FILE"
    
    run confirm_action "Title" "Message" "Action"
    
    [ "$status" -eq 1 ]
}

@test "delete_worktree_interactive asks for confirmation on dirty worktree" {
    # Create a worktree with changes
    git branch feature/dirty
    local wt_path="$WORKTREE_BASE/repo/feature/dirty"
    mkdir -p "$(dirname "$wt_path")"
    git worktree add "$wt_path" feature/dirty
    echo "changes" > "$wt_path/dirty_file"
    
    # Mock fzf to say "No" (cancel deletion)
    echo "No" > "$FZF_OUTPUT_FILE"
    
    # Run delete
    run delete_worktree_interactive "  feature/dirty" < /dev/null
    
    # Should fail (return 1) because we said No
    [ "$status" -eq 1 ]
    
    # Should verify that confirm_action was actually triggered
    grep -q "WARNING: Uncommitted changes" "$FZF_ARGS_FILE"
    
    # Worktree should still exist
    [ -d "$wt_path" ]
}

@test "delete_worktree_interactive proceeds when user confirms" {
    # Create a worktree with changes
    git branch feature/dirty-confirm
    local wt_path="$WORKTREE_BASE/repo/feature/dirty-confirm"
    mkdir -p "$(dirname "$wt_path")"
    git worktree add "$wt_path" feature/dirty-confirm
    echo "changes" > "$wt_path/dirty_file"
    
    # Mock fzf to say "Yes" (confirm deletion)
    echo "Yes" > "$FZF_OUTPUT_FILE"
    
    run delete_worktree_interactive "  feature/dirty-confirm" < /dev/null
    
    # Should succeed
    [ "$status" -eq 0 ]
    
    # Worktree should be gone
    [ ! -d "$wt_path" ]
}

@test "delete_worktree_interactive deletes clean worktree without confirmation" {
    # Create a clean worktree
    git branch feature/clean
    local wt_path="$WORKTREE_BASE/repo/feature/clean"
    mkdir -p "$(dirname "$wt_path")"
    git worktree add "$wt_path" feature/clean
    
    # Clear fzf args to ensure it wasn't called
    rm -f "$FZF_ARGS_FILE"
    
    run delete_worktree_interactive "  feature/clean" < /dev/null
    
    # Should succeed
    [ "$status" -eq 0 ]
    
    # Worktree should be gone
    [ ! -d "$wt_path" ]
    
    # fzf should NOT have been called (no confirmation needed)
    [ ! -f "$FZF_ARGS_FILE" ]
}

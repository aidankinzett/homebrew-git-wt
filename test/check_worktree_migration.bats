#!/usr/bin/env bats

# Tests for check_worktree_migration function

load test_helper

setup() {
    setup_test_git_repo
    load_git_wt
    
    # Set up a project name for testing
    git remote add origin https://github.com/testuser/test-repo.git

    CURRENT_BASE="$TEST_TEMP_DIR/current/base"
    GLOBAL_BASE="$TEST_TEMP_DIR/global/base"
    ENV_BASE="$TEST_TEMP_DIR/env/base"
    OTHER_BASE="$TEST_TEMP_DIR/other/base"

    # Canonicalize paths since they'll be validated by get_worktree_base
    CURRENT_BASE=$(canonicalize_path "$CURRENT_BASE")
    GLOBAL_BASE=$(canonicalize_path "$GLOBAL_BASE")
    ENV_BASE=$(canonicalize_path "$ENV_BASE")
    OTHER_BASE=$(canonicalize_path "$OTHER_BASE")

    # Save original configs
    ORIGINAL_LOCAL_CONFIG=$(git config --local --get worktree.basepath 2>/dev/null || true)
    ORIGINAL_GLOBAL_CONFIG=$(git config --global --get worktree.basepath 2>/dev/null || true)
    ORIGINAL_ENV_VAR="$GIT_WT_BASE"
    
    # Clean up any existing configs
    git config --local --unset worktree.basepath 2>/dev/null || true
    git config --global --unset worktree.basepath 2>/dev/null || true
    unset GIT_WT_BASE
}

teardown() {
    # Restore original configs
    if [[ -n "$ORIGINAL_LOCAL_CONFIG" ]]; then
        git config --local worktree.basepath "$ORIGINAL_LOCAL_CONFIG"
    else
        git config --local --unset worktree.basepath 2>/dev/null || true
    fi
    if [[ -n "$ORIGINAL_GLOBAL_CONFIG" ]]; then
        git config --global worktree.basepath "$ORIGINAL_GLOBAL_CONFIG"
    else
        git config --global --unset worktree.basepath 2>/dev/null || true
    fi
    if [[ -n "$ORIGINAL_ENV_VAR" ]]; then
        export GIT_WT_BASE="$ORIGINAL_ENV_VAR"
    else
        unset GIT_WT_BASE
    fi
    
    teardown_test_git_repo
}

refresh_worktree_base() {
    # shellcheck disable=SC2034  # WORKTREE_BASE is used by sourced git-wt script
    WORKTREE_BASE=$(get_worktree_base)
}

@test "check_worktree_migration does nothing when no worktrees exist elsewhere" {
    git config --local worktree.basepath "$CURRENT_BASE"
    refresh_worktree_base
    
    run check_worktree_migration
    
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "check_worktree_migration warns when worktrees exist in default location" {
    git config --local worktree.basepath "$CURRENT_BASE"
    refresh_worktree_base
    
    # Create worktrees in default location
    mkdir -p "$HOME/Git/.worktrees/test-repo"
    echo "worktree" > "$HOME/Git/.worktrees/test-repo/branch1"
    
    run check_worktree_migration
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Migration Notice"* ]]
    [[ "$output" == *"$HOME/Git/.worktrees/test-repo"* ]]
}

@test "check_worktree_migration warns when worktrees exist in global config location" {
    git config --local worktree.basepath "$CURRENT_BASE"
    git config --global worktree.basepath "$GLOBAL_BASE"
    refresh_worktree_base
    
    # Create worktrees in global config location
    mkdir -p "$GLOBAL_BASE/test-repo"
    echo "worktree" > "$GLOBAL_BASE/test-repo/branch1"
    
    run check_worktree_migration
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Migration Notice"* ]]
    [[ "$output" == *"$GLOBAL_BASE/test-repo"* ]]
}

@test "check_worktree_migration warns when worktrees exist in environment variable location" {
    git config --local worktree.basepath "$CURRENT_BASE"
    export GIT_WT_BASE="$ENV_BASE"
    refresh_worktree_base
    
    # Create worktrees in env var location
    mkdir -p "$ENV_BASE/test-repo"
    echo "worktree" > "$ENV_BASE/test-repo/branch1"
    
    run check_worktree_migration
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Migration Notice"* ]]
    [[ "$output" == *"$ENV_BASE/test-repo"* ]]
}

@test "check_worktree_migration shows multiple locations when worktrees exist in multiple places" {
    git config --local worktree.basepath "$CURRENT_BASE"
    refresh_worktree_base
    
    # Create worktrees in multiple locations
    mkdir -p "$HOME/Git/.worktrees/test-repo"
    echo "worktree1" > "$HOME/Git/.worktrees/test-repo/branch1"
    
    mkdir -p "$OTHER_BASE/test-repo"
    echo "worktree2" > "$OTHER_BASE/test-repo/branch2"
    
    # Set global config to the other location
    git config --global worktree.basepath "$OTHER_BASE"
    
    run check_worktree_migration
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Migration Notice"* ]]
    [[ "$output" == *"$HOME/Git/.worktrees/test-repo"* ]]
    [[ "$output" == *"$OTHER_BASE/test-repo"* ]]
}

@test "check_worktree_migration does not warn about current location" {
    git config --local worktree.basepath "$CURRENT_BASE"
    refresh_worktree_base
    
    # Create worktrees in current location
    mkdir -p "$CURRENT_BASE/test-repo"
    echo "worktree" > "$CURRENT_BASE/test-repo/branch1"
    
    run check_worktree_migration
    
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "check_worktree_migration ignores empty directories" {
    git config --local worktree.basepath "$CURRENT_BASE"
    refresh_worktree_base
    
    # Create empty directory in default location
    mkdir -p "$HOME/Git/.worktrees/test-repo"
    
    run check_worktree_migration
    
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "check_worktree_migration handles repositories without remotes" {
    # Remove remote
    git remote remove origin
    
    # Set current base
    git config --local worktree.basepath "$CURRENT_BASE"
    refresh_worktree_base
    
    # Should not error, just return early
    run check_worktree_migration
    
    [ "$status" -eq 0 ]
}


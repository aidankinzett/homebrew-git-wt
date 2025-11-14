#!/usr/bin/env bats

# Tests for get_worktree_base function

load test_helper

setup() {
    setup_test_git_repo
    load_git_wt
    
    # Save original global config if it exists
    ORIGINAL_GLOBAL_CONFIG=$(git config --global --get worktree.basepath 2>/dev/null || true)
    ORIGINAL_ENV_VAR="$GIT_WT_BASE"
    
    LOCAL_BASE="$TEST_TEMP_DIR/local/base"
    GLOBAL_BASE="$TEST_TEMP_DIR/global/base"
    ENV_BASE="$TEST_TEMP_DIR/env/base"
    DEFAULT_BASE="$HOME/Git/.worktrees"

    # Clean up any existing configs
    git config --local --unset worktree.basepath 2>/dev/null || true
    git config --global --unset worktree.basepath 2>/dev/null || true
    unset GIT_WT_BASE
}

teardown() {
    # Restore original configs
    git config --local --unset worktree.basepath 2>/dev/null || true
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

last_line() {
    echo "${lines[${#lines[@]}-1]}"
}

@test "get_worktree_base uses default when no config is set" {
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$DEFAULT_BASE" ]
}

@test "get_worktree_base prioritizes local git config over global" {
    git config --local worktree.basepath "$LOCAL_BASE"
    git config --global worktree.basepath "$GLOBAL_BASE"
    
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$LOCAL_BASE" ]
}

@test "get_worktree_base prioritizes local git config over environment variable" {
    git config --local worktree.basepath "$LOCAL_BASE"
    export GIT_WT_BASE="$ENV_BASE"
    
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$LOCAL_BASE" ]
}

@test "get_worktree_base prioritizes global git config over environment variable" {
    git config --global worktree.basepath "$GLOBAL_BASE"
    export GIT_WT_BASE="$ENV_BASE"
    
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$GLOBAL_BASE" ]
}

@test "get_worktree_base uses environment variable when no git config" {
    export GIT_WT_BASE="$ENV_BASE"
    
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$ENV_BASE" ]
}

@test "get_worktree_base expands tilde in local config" {
    git config --local worktree.basepath "~/custom/worktrees"
    
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$HOME/custom/worktrees" ]
}

@test "get_worktree_base expands tilde in global config" {
    git config --global worktree.basepath "~/custom/worktrees"
    
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$HOME/custom/worktrees" ]
}

@test "get_worktree_base expands tilde in environment variable" {
    export GIT_WT_BASE="~/custom/worktrees"
    
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$HOME/custom/worktrees" ]
}

@test "get_worktree_base falls back when local config is invalid" {
    git config --local worktree.basepath "relative/path"
    git config --global worktree.basepath "$GLOBAL_BASE"
    
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$GLOBAL_BASE" ]
}

@test "get_worktree_base falls back when global config is invalid" {
    git config --global worktree.basepath "relative/path"
    export GIT_WT_BASE="$ENV_BASE"
    
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$ENV_BASE" ]
}

@test "get_worktree_base falls back when environment variable is invalid" {
    export GIT_WT_BASE="relative/path"
    
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$DEFAULT_BASE" ]
}

@test "get_worktree_base falls back through all invalid configs to default" {
    git config --local worktree.basepath "relative/path"
    git config --global worktree.basepath "another/relative/path"
    export GIT_WT_BASE="yet/another/relative/path"
    
    run get_worktree_base
    
    [ "$status" -eq 0 ]
    [ "$(last_line)" = "$DEFAULT_BASE" ]
}


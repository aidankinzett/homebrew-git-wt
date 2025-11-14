#!/usr/bin/env bats

# Tests for cmd_config function

load test_helper

setup() {
    setup_test_git_repo
    load_git_wt
    
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

@test "cmd_config shows default path when no config is set" {
    run cmd_config
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Current worktree base path"* ]]
    [[ "$output" == *"$HOME/Git/.worktrees"* ]]
    [[ "$output" == *"Default"* ]]
    [[ "$output" == *"[active]"* ]]
}

@test "cmd_config shows local config as active when set" {
    git config --local worktree.basepath "/tmp/local/path"
    
    run cmd_config
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"/tmp/local/path"* ]]
    [[ "$output" == *"Local git config"* ]]
    [[ "$output" == *"[active]"* ]]
}

@test "cmd_config shows global config as active when no local config" {
    git config --global worktree.basepath "/tmp/global/path"
    
    run cmd_config
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"/tmp/global/path"* ]]
    [[ "$output" == *"Global git config"* ]]
    [[ "$output" == *"[active]"* ]]
}

@test "cmd_config shows environment variable as active when no git config" {
    export GIT_WT_BASE="/tmp/env/path"
    
    run cmd_config
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"/tmp/env/path"* ]]
    [[ "$output" == *"Environment var"* ]]
    [[ "$output" == *"[active]"* ]]
}

@test "cmd_config shows local config overrides global config" {
    git config --local worktree.basepath "/tmp/local/path"
    git config --global worktree.basepath "/tmp/global/path"
    
    run cmd_config
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Local git config"* ]]
    [[ "$output" == *"[active]"* ]]
    [[ "$output" == *"Global git config"* ]]
    [[ "$output" == *"(overridden by local)"* ]]
}

@test "cmd_config shows local config overrides environment variable" {
    git config --local worktree.basepath "/tmp/local/path"
    export GIT_WT_BASE="/tmp/env/path"
    
    run cmd_config
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Local git config"* ]]
    [[ "$output" == *"[active]"* ]]
    [[ "$output" == *"Environment var"* ]]
    [[ "$output" == *"(overridden)"* ]]
}

@test "cmd_config shows global config overrides environment variable" {
    git config --global worktree.basepath "/tmp/global/path"
    export GIT_WT_BASE="/tmp/env/path"
    
    run cmd_config
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Global git config"* ]]
    [[ "$output" == *"[active]"* ]]
    [[ "$output" == *"Environment var"* ]]
    [[ "$output" == *"(overridden)"* ]]
}

@test "cmd_config shows all configuration sources" {
    git config --local worktree.basepath "/tmp/local/path"
    git config --global worktree.basepath "/tmp/global/path"
    export GIT_WT_BASE="/tmp/env/path"
    
    run cmd_config
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Local git config"* ]]
    [[ "$output" == *"Global git config"* ]]
    [[ "$output" == *"Environment var"* ]]
    [[ "$output" == *"Default"* ]]
}

@test "cmd_config shows not set for unconfigured sources" {
    run cmd_config
    
    [ "$status" -eq 0 ]
    [[ "$output" == *"Local git config"* ]]
    [[ "$output" == *"(not set)"* ]]
    [[ "$output" == *"Global git config"* ]]
    [[ "$output" == *"(not set)"* ]]
    [[ "$output" == *"Environment var"* ]]
    [[ "$output" == *"(not set)"* ]]
}


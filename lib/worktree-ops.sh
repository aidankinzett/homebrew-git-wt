#!/bin/bash

# Core worktree operations
#
# Prerequisites:
#   - Required functions (must be sourced before this file):
#     * get_project_name() - from lib/git-utils.sh
#     * get_main_worktree() - from lib/git-utils.sh
#   - Required environment variables:
#     * WORKTREE_BASE - base path for storing worktrees (e.g., ~/Git/.worktrees)
#   - These are typically set up by the main git-wt script before sourcing this file

# Cache for git worktree list --porcelain output
# This prevents redundant git calls (500+ per fuzzy finder session → 1)
_worktree_list_cache=""
_worktree_list_cache_valid=0

# Get cached worktree list
# Returns the output of 'git worktree list --porcelain' from cache
# Caches result in memory for the duration of script execution
get_worktree_list_cached() {
    if [[ $_worktree_list_cache_valid -eq 0 ]]; then
        _worktree_list_cache=$(git worktree list --porcelain 2>/dev/null)
        _worktree_list_cache_valid=1
    fi
    echo "$_worktree_list_cache"
}

# Invalidate worktree cache
# Call this after any operation that modifies worktrees (add/remove)
invalidate_worktree_cache() {
    _worktree_list_cache=""
    _worktree_list_cache_valid=0
}

# Check if branch has a worktree
# Checks both the expected location and git's registered worktrees
has_worktree() {
    local branch="$1"

    # First check the expected location based on WORKTREE_BASE
    local project_name
    project_name=$(get_project_name)
    local expected_path="$WORKTREE_BASE/$project_name/$branch"
    if [[ -d "$expected_path" ]]; then
        return 0
    fi

    # Also check git's registered worktrees (handles worktrees in different locations)
    # This finds worktrees even if they're in legacy locations
    # Use cached list to avoid redundant git calls
    if get_worktree_list_cached | grep -q "^worktree .*/$branch$"; then
        return 0
    fi

    return 1
}

# Get worktree path for branch
# Returns the actual path where the worktree is located
# Checks git's registered worktrees first (handles legacy locations), then falls back to expected path
get_worktree_path() {
    local branch="$1"

    # First try to find the actual worktree from git's registry
    # This handles worktrees in legacy or non-standard locations
    # Use cached list to avoid redundant git calls
    local worktree_path
    worktree_path=$(get_worktree_list_cached | grep "^worktree .*/$branch$" | awk '{print $2}')
    if [[ -n "$worktree_path" ]]; then
        echo "$worktree_path"
        return
    fi

    # Fall back to the expected path based on WORKTREE_BASE
    local project_name
    project_name=$(get_project_name)
    echo "$WORKTREE_BASE/$project_name/$branch"
}

# Check if a worktree is stale and safe to prune
is_worktree_stale() {
    local branch="$1"
    local worktree_path="$2"

    # Determine main branch name
    local main_branch
    main_branch=$(git config --get init.defaultBranch 2>/dev/null || echo "main")

    # Try main, fallback to master if main doesn't exist
    if ! git show-ref --verify --quiet "refs/heads/$main_branch" 2>/dev/null; then
        main_branch="master"
    fi

    # Check if branch is merged into main/master
    # Use awk for literal string matching to avoid regex injection
    if git branch --merged "$main_branch" 2>/dev/null | awk -v b="$branch" '$0 ~ "^[* ]*" b "$" {found=1} END {exit !found}'; then
        # Safety guardrail: Check for uncommitted changes (use git -C to avoid changing shell state)
        local status
        if ! status=$(git -C "$worktree_path" status --porcelain 2>/dev/null); then
            return 1
        fi
        if [[ -z "$status" ]]; then
            return 0  # Is stale and safe to prune
        fi
    fi

    return 1  # Not stale or not safe to prune
}

# Auto-prune stale worktrees (merged branches with no uncommitted changes)
auto_prune_stale_worktrees() {
    local project_name
    project_name=$(get_project_name)
    local pruned=0
    local space_freed=0

    # Get list of worktrees (skip main worktree)
    local main_worktree
    main_worktree=$(get_main_worktree)

    while IFS= read -r line; do
        # Match lines starting with "worktree" from git worktree list output
        if [[ "$line" =~ ^worktree ]]; then
            local wt_path="${line#worktree }"

            # Skip main worktree
            [[ "$wt_path" == "$main_worktree" ]] && continue

            # Get branch for this worktree
            local branch
            branch=$(git -C "$wt_path" branch --show-current 2>/dev/null)

            # Check if stale and prune
            if [[ -n "$branch" ]] && is_worktree_stale "$branch" "$wt_path"; then
                # Calculate size before removal (in KB)
                local size
                size=$(du -sk "$wt_path" 2>/dev/null | awk '{print $1}')

                # Remove worktree
                if git worktree remove --force "$wt_path" 2>/dev/null; then
                    pruned=$((pruned + 1))
                    space_freed=$((space_freed + size))

                    # Invalidate cache since we removed a worktree
                    invalidate_worktree_cache

                    # Clean up empty parent directories
                    local parent_dir
                    parent_dir="$(dirname "$wt_path")"
                    if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]]; then
                        rmdir "$parent_dir" 2>/dev/null
                    fi
                fi
            fi
        fi
    done < <(get_worktree_list_cached)

    # Report if anything was pruned
    if [[ $pruned -gt 0 ]]; then
        local space_mb=$((space_freed / 1024))
        echo "[Auto-pruned $pruned merged worktree(s): ${space_mb}MB freed]"
    fi
}

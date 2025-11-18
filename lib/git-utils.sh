#!/bin/bash

# Git utility functions

# Cache for get_main_worktree()
_main_worktree_cache=""

# Check if we're in a git repository
# Returns 1 if not in a git repo, 0 if in a git repo
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not a git repository"
        return 1
    fi
    return 0
}

# Get the project name from git repo
# Returns the project name on success, returns 1 with error message on failure
get_project_name() {
    # Try to get from remote URL first
    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null)

    local project_name
    if [[ -n "$remote_url" ]]; then
        # Extract project name from URL using basename (strips .git suffix automatically)
        project_name=$(basename -s .git "$remote_url")
    else
        # Fallback to directory name
        local toplevel
        if ! toplevel=$(git rev-parse --show-toplevel 2>&1); then
            echo "Failed to get git repository root: $toplevel" >&2
            return 1
        fi
        project_name=$(basename "$toplevel")
    fi

    if [[ -z "$project_name" ]]; then
        echo "Failed to determine project name" >&2
        return 1
    fi

    echo "$project_name"
}

# Get the main worktree path
# Returns the path on success, exits with error on failure
get_main_worktree() {
    # Return cached result if available
    if [[ -n "$_main_worktree_cache" ]]; then
        echo "$_main_worktree_cache"
        return 0
    fi

    local output
    if ! output=$(git worktree list 2>&1); then
        echo "Failed to get worktree list" >&2
        return 1
    fi

    local main_worktree
    main_worktree=$(echo "$output" | head -n 1 | awk '{print $1}')

    if [[ -z "$main_worktree" ]]; then
        echo "No worktree found" >&2
        return 1
    fi

    # Cache the result
    _main_worktree_cache="$main_worktree"
    echo "$main_worktree"
}

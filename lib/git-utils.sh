#!/bin/bash

# Git utility functions

# Check if we're in a git repository
check_git_repo() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        error "Not a git repository"
        exit 1
    fi
}

# Get the project name from git repo
get_project_name() {
    # Try to get from remote URL first
    local remote_url
    remote_url=$(git config --get remote.origin.url 2>/dev/null)

    local project_name
    if [[ -n "$remote_url" ]]; then
        # Extract project name from URL (handles both SSH and HTTPS)
        project_name=$(echo "$remote_url" | sed -E 's/.*[:/]([^/]+)\/([^/]+)(\.git)?$/\2/' | sed 's/\.git$//')
    else
        # Fallback to directory name
        project_name=$(basename "$(git rev-parse --show-toplevel)")
    fi

    echo "$project_name"
}

# Get the main worktree path
get_main_worktree() {
    git worktree list | head -n 1 | awk '{print $1}'
}

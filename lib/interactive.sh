#!/bin/bash

# Interactive confirmation and deletion functions

# Show a confirmation dialog with custom title, message, and action using fzf
# Returns: 0 if user selects Yes, 1 if user selects No or cancels
confirm_action() {
    local title="$1"
    local message="$2"
    local action="$3"
    
    # Create a header with title, message, and action
    local header="$title

$message

$action

Select an option:"
    
    local selection
    selection=$(printf "No\nYes" | fzf --prompt "? " --height 7 --border --header "$header" 2>/dev/null)
    local fzf_exit_code=$?
    
    if [[ $fzf_exit_code -eq 0 && "$selection" == "Yes" ]]; then
        return 0 # Yes
    else
        return 1 # No or cancel
    fi
}

# Delete a worktree interactively, prompting for confirmation if it has uncommitted changes
delete_worktree_interactive() {
    local line="$1"
    # Extract branch name (remove leading spaces and indicators)
    local branch
    branch=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/^[✓ ]*//')
    
    if [[ -z "$branch" ]]; then
        error "No branch selected."
        return 1
    fi
    
    local worktree_path
    worktree_path=$(get_worktree_path "$branch")
    
    if [[ ! -d "$worktree_path" ]]; then
        error "Worktree for '$branch' does not exist."
        return 1
    fi
    
    # Check if worktree has uncommitted changes
    local status
    status=$(git -C "$worktree_path" status --porcelain 2>/dev/null)
    
    if [[ -n "$status" ]]; then
        # Dirty worktree - ask for confirmation
        if ! confirm_action \
            "WARNING: Uncommitted changes" \
            "The worktree for '$branch' has uncommitted changes." \
            "Delete anyway?"; then
            return 1
        fi
    fi
    
    # Delete the worktree
    if git worktree remove --force "$worktree_path" >/dev/null 2>&1; then
        # Clean up empty parent directories
        local parent_dir
        parent_dir="$(dirname "$worktree_path")"
        if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]]; then
            rmdir "$parent_dir" 2>/dev/null
        fi
        return 0
    else
        error "Failed to delete worktree."
        return 1
    fi
}

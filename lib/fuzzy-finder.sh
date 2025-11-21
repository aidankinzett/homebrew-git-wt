#!/bin/bash

# Fuzzy finder functionality

# Check if fzf is installed
check_fzf() {
    if ! command -v fzf &> /dev/null; then
        error "fzf is required for interactive mode."
        echo ""
        info "Install fzf:"
        echo "  macOS:  brew install fzf"
        echo "  Linux:  apt install fzf  (or your package manager)"
        echo ""
        info "Alternatively, use direct mode:"
        echo "  git-wt <branch-name>"
        echo "  git-wt --list"
        exit 1
    fi
}

# Extracts the branch name from a line of fzf output
extract_branch_from_line() {
    local line="$1"
    echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[✓ ]*//' | sed 's/ \[.*\]$//'
}

# Shows a multi-line error message
show_multiline_error() {
    local title="$1"
    local message="$2"
    error "$title"
    echo "$message"
}

# Generate branch list with indicators for fuzzy finder
# Parameters:
#   $1: mode - "local-only" to only show local branches, "all" to show all branches
generate_branch_list() {
    local mode="${1:-all}"
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "")

    # Get branches based on mode
    local branches=()

    # Local branches
    while IFS= read -r branch; do
        branches+=("$branch|local")
    done < <(git branch --format='%(refname:short)' 2>/dev/null)

    # Remote branches (excluding HEAD) - only if mode is "all"
    if [[ "$mode" == "all" ]]; then
        while IFS= read -r branch; do
            local branch_name="${branch#origin/}"
            # Skip if this is HEAD or if we already have it as local
            # Check if branch already exists in array with "|local" suffix using literal string match
            if [[ "$branch_name" != "HEAD" ]] && ! [[ " ${branches[*]} " == *" $branch_name|local "* ]]; then
                branches+=("$branch_name|remote")
            fi
        done < <(git branch -r --format='%(refname:short)' 2>/dev/null | grep "^origin/")
    fi

    # Sort and format branches with indicators
    local formatted_branches=()

    # First add current branch
    for branch_info in "${branches[@]}"; do
        local branch="${branch_info%|*}"
        local type="${branch_info#*|}"

        if [[ "$branch" == "$current_branch" ]]; then
            formatted_branches+=("$(format_branch_line "$branch" "$type" "$current_branch")")
        fi
    done

    # Then add branches with worktrees
    for branch_info in "${branches[@]}"; do
        local branch="${branch_info%|*}"
        local type="${branch_info#*|}"

        if [[ "$branch" != "$current_branch" ]] && has_worktree "$branch"; then
            formatted_branches+=("$(format_branch_line "$branch" "$type" "$current_branch")")
        fi
    done

    # Then add other local branches
    for branch_info in "${branches[@]}"; do
        local branch="${branch_info%|*}"
        local type="${branch_info#*|}"

        if [[ "$branch" != "$current_branch" ]] && ! has_worktree "$branch" && [[ "$type" == "local" ]]; then
            formatted_branches+=("$(format_branch_line "$branch" "$type" "$current_branch")")
        fi
    done

    # Finally add remote-only branches
    for branch_info in "${branches[@]}"; do
        local branch="${branch_info%|*}"
        local type="${branch_info#*|}"

        if [[ "$branch" != "$current_branch" ]] && ! has_worktree "$branch" && [[ "$type" == "remote" ]]; then
            formatted_branches+=("$(format_branch_line "$branch" "$type" "$current_branch")")
        fi
    done

    printf '%s\n' "${formatted_branches[@]}"
}

# Format a single branch line with indicators
format_branch_line() {
    local branch="$1"
    local type="$2"
    local current_branch="$3"

    local indicator=""
    local suffix=""

    # Add worktree indicator
    if has_worktree "$branch"; then
        indicator="\033[0;32m✓\033[0m "  # Green checkmark
    else
        indicator="  "
    fi

    # Add status suffix
    if [[ "$branch" == "$current_branch" ]]; then
        suffix=" \033[0;33m[current]\033[0m"  # Yellow
    elif [[ "$type" == "remote" ]]; then
        suffix=" \033[0;36m[remote only]\033[0m"  # Cyan
    fi

    echo -e "${indicator}${branch}${suffix}"
}

# Show worktree info for preview pane
show_worktree_info() {
    local line="$1"
    local branch
    branch=$(extract_branch_from_line "$line")

    if [[ -z "$branch" ]]; then
        echo "No branch selected."
        return
    fi

    echo "Branch: $branch"
    echo ""

    # Check if worktree exists
    local worktree_path
    worktree_path=$(get_worktree_path "$branch")

    if [[ -d "$worktree_path" ]]; then
        echo "Worktree: $worktree_path"

        # Git status (use git -C to avoid changing working directory)
        local status
        status=$(git -C "$worktree_path" status --porcelain 2>/dev/null)
        if [[ -z "$status" ]]; then
            echo "Status: Clean ✓"
        else
            echo "Status: Has uncommitted changes."
        fi

        # Last modified time
        local last_modified
        # Detect platform and use appropriate stat command
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS uses -f flag
            last_modified=$(find "$worktree_path" -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | awk '{print $1}')
        else
            # Linux uses -c flag
            last_modified=$(find "$worktree_path" -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -exec stat -c "%Y %n" {} \; 2>/dev/null | sort -rn | head -1 | awk '{print $1}')
        fi
        if [[ -n "$last_modified" ]]; then
            local mod_date
            mod_date=$(date -r "$last_modified" "+%Y-%m-%d %H:%M" 2>/dev/null)
            echo "Last modified: $mod_date"
        fi

        # Directory size
        local total_size
        total_size=$(du -sh "$worktree_path" 2>/dev/null | awk '{print $1}')
        echo "Size: $total_size"

        if [[ -d "$worktree_path/node_modules" ]]; then
            local nm_size
            nm_size=$(du -sh "$worktree_path/node_modules" 2>/dev/null | awk '{print $1}')
            echo "  (node_modules: $nm_size)"
        fi

        echo ""
        echo "Recent commits:"
        git -C "$worktree_path" log --oneline --color=always -n 3 2>/dev/null | sed 's/^/  /'

    else
        echo "Worktree: Not created."
        echo ""

        # Check if branch exists locally or remotely
        if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
            echo "Branch type: Local."
            echo ""
            echo "Recent commits:"
            git log --oneline --color=always -n 3 "$branch" 2>/dev/null | sed 's/^/  /' || echo "  No commits yet."
        elif git ls-remote --heads origin "$branch" 2>/dev/null | grep -q "$branch"; then
            echo "Branch type: Remote only (origin/$branch)."
            echo ""
            echo "Recent commits:"
            git log --oneline --color=always -n 3 "origin/$branch" 2>/dev/null | sed 's/^/  /' || echo "  Unable to fetch commits."
        else
            # New branch - show what it will be created from
            local current_branch
            current_branch=$(git branch --show-current 2>/dev/null)
            if [[ -n "$current_branch" ]]; then
                echo "Branch type: New (will be created from '$current_branch')."
            else
                # Detached HEAD - show commit hash
                local commit_hash
                commit_hash=$(git rev-parse --short HEAD 2>/dev/null)
                echo "Branch type: New (will be created from commit $commit_hash)."
            fi
        fi
    fi
}

# Open or create worktree (called from fuzzy finder)
open_or_create_worktree() {
    local line="$1"
    local branch
    branch=$(extract_branch_from_line "$line")

    if [[ -z "$branch" ]]; then
        error "No branch selected."
        return 1
    fi

    local worktree_path
    worktree_path=$(get_worktree_path "$branch")

    # If worktree exists, just open it
    if [[ -d "$worktree_path" ]]; then
        info "Opening existing worktree: $worktree_path"

        open_in_editor "$worktree_path"
    else
        # Create new worktree
        cmd_add "$branch"
    fi
}

# Internal function to handle the core logic of deleting a worktree
_delete_worktree_internal() {
    local branch="$1"
    local worktree_path="$2"
    local force_prompt="$3"

    local loader_info
    loader_info=$(show_loading "Deleting worktree for '$branch'...")
    local loader_pid
    loader_pid=$(echo "$loader_info" | cut -d' ' -f1)
    local flag_file
    flag_file=$(echo "$loader_info" | cut -d' ' -f2)

    local error_msg
    if ! error_msg=$(git worktree remove "$worktree_path" 2>&1); then
        hide_loading "$loader_pid" "$flag_file"
        show_multiline_error "Failed to delete worktree." "$error_msg"
        if ask_yes_no "$force_prompt"; then
            loader_info=$(show_loading "Force deleting worktree...")
            loader_pid=$(echo "$loader_info" | cut -d' ' -f1)
            flag_file=$(echo "$loader_info" | cut -d' ' -f2)
            if git worktree remove --force "$worktree_path" >/dev/null 2>&1; then
                hide_loading "$loader_pid" "$flag_file"
                return 0 # Success
            else
                hide_loading "$loader_pid" "$flag_file"
                error "Failed to force-delete worktree."
                return 1 # Failure
            fi
        else
            return 2 # Cancelled
        fi
    else
        hide_loading "$loader_pid" "$flag_file"
        return 0 # Success
    fi
}

# Delete a worktree with interactive prompts and loading animations
delete_worktree_with_check() {
    local line="$1"
    local branch
    branch=$(extract_branch_from_line "$line")

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

    _delete_worktree_internal "$branch" "$worktree_path" "Force delete?"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        success "Worktree for '$branch' deleted successfully."
        # Clean up empty parent directories
        local parent_dir
        parent_dir="$(dirname "$worktree_path")"
        if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]]; then
            rmdir "$parent_dir" 2>/dev/null
        fi
        return 0
    elif [[ $exit_code -eq 2 ]]; then
        info "Deletion cancelled."
        return 1
    else
        return 1
    fi
}

# Recreate a worktree with interactive prompts and loading animations
recreate_worktree() {
    local line="$1"
    local branch
    branch=$(extract_branch_from_line "$line")

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

    _delete_worktree_internal "$branch" "$worktree_path" "Force recreate? (will delete uncommitted changes)"
    local exit_code=$?

    if [[ $exit_code -eq 0 ]]; then
        success "Old worktree removed. Creating fresh one..."
        echo ""
        # Clean up empty parent directories
        local parent_dir
        parent_dir="$(dirname "$worktree_path")"
        if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]]; then
            rmdir "$parent_dir" 2>/dev/null
        fi
        cmd_add "$branch"
    elif [[ $exit_code -eq 2 ]]; then
        info "Recreation cancelled."
        return 1
    else
        return 1
    fi
}


# Interactive fuzzy finder mode
cmd_interactive() {
    check_git_repo || exit 1
    check_fzf

    # Check for migration notice
    check_worktree_migration

    # Start async auto-prune if enabled
    if [[ "$(git config --get worktree.autoprune 2>/dev/null)" == "true" ]]; then
        # Fork to background, redirect output to temp log
        local prune_log
        prune_log=$(mktemp "${TMPDIR:-/tmp}/git-wt-prune.XXXXXX")
        (auto_prune_stale_worktrees > "$prune_log" 2>&1) &
    fi

    # Export functions so they're available to fzf subshells.
    # This is necessary because fzf's `execute` binding runs the command in a
    # new shell, and these functions need to be available to it.
    export -f show_worktree_info
    export -f open_or_create_worktree
    export -f delete_worktree_with_check
    export -f recreate_worktree
    export -f has_worktree
    export -f get_worktree_path
    export -f get_project_name
    export -f format_branch_line
    export -f generate_branch_list
    export -f cmd_add
    export -f check_git_repo
    export -f get_main_worktree
    export -f symlink_env_files
    export -f detect_package_manager
    export -f check_worktree_migration
    export -f is_worktree_stale
    export -f auto_prune_stale_worktrees
    export -f error
    export -f success
    export -f info
    export -f warning
    export -f show_loading
    export -f hide_loading
    export -f ask_yes_no
    export -f extract_branch_from_line
    export -f show_multiline_error
    export -f get_editor
    export -f open_in_editor
    export WORKTREE_BASE
    export RED
    export GREEN
    export YELLOW
    export BLUE
    export NC

    local script_path="$0"

    # Create a named pipe (FIFO) for async branch loading
    local fifo
    fifo=$(mktemp -u)
    mkfifo "$fifo"

    # Clean up FIFO on exit or interrupt
    trap 'rm -f "$fifo"' EXIT INT TERM

    # Background process to generate branches asynchronously
    (
        # First, output local branches immediately
        generate_branch_list "local-only"

        # Now fetch remote branches in background
        local current_branch
        current_branch=$(git branch --show-current 2>/dev/null || echo "")
        local branches=()

        # Get local branches first (for deduplication)
        while IFS= read -r branch; do
            branches+=("$branch|local")
        done < <(git branch --format='%(refname:short)' 2>/dev/null)

        # Now get remote-only branches
        while IFS= read -r branch; do
            local branch_name="${branch#origin/}"
            # Skip if this is HEAD or if we already have it as local
            # Check if branch already exists in array with "|local" suffix using literal string match
            if [[ "$branch_name" != "HEAD" ]] && ! [[ " ${branches[*]} " == *" $branch_name|local "* ]]; then
                format_branch_line "$branch_name" "remote" "$current_branch"
            fi
        done < <(git branch -r --format='%(refname:short)' 2>/dev/null | grep "^origin/")
    ) > "$fifo" &

    local bg_pid=$!

    # Launch fuzzy finder with the FIFO as input
    local result
    result=$(fzf \
        --ansi \
        --print-query \
        --preview "$script_path __preview {}" \
        --preview-window right:50% \
        --prompt "Select branch > " \
        --header "[Enter] Open/Create  [d] Delete  [r] Recreate  [Esc] Cancel" \
        --border \
        --height 100% \
        --no-select-1 \
        --bind "d:execute($script_path __delete {})+reload($script_path __list-branches)" \
        --bind "r:execute($script_path __recreate {})+reload($script_path __list-branches)" < "$fifo")
    # Note: `execute` is used instead of `execute-silent` to ensure that the
    # interactive prompts and loading animations from the `ui.sh` library are
    # visible to the user. `execute-silent` would suppress this output.

    # Wait for background process to finish
    wait $bg_pid 2>/dev/null

    # Handle selection - fzf with --print-query outputs query on first line, selection on second
    if [[ -n "$result" ]]; then
        local query
        query=$(echo "$result" | head -n 1)
        local selected
        selected=$(echo "$result" | sed -n '2p')

        echo ""
        # If user selected an item from the list, use that. Otherwise use the query (new branch name)
        if [[ -n "$selected" ]]; then
            open_or_create_worktree "$selected"
        elif [[ -n "$query" ]]; then
            open_or_create_worktree "$query"
        else
            info "Cancelled."
        fi
    else
        echo ""
        info "Cancelled."
    fi
}

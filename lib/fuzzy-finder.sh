#!/bin/bash

# Fuzzy finder functionality

# Check if fzf is installed
check_fzf() {
    if ! command -v fzf &> /dev/null; then
        error "fzf is required for interactive mode"
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

    # Strip ANSI color codes and extract branch name
    local branch
    branch=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[✓ ]*//' | sed 's/ \[.*\]$//')

    if [[ -z "$branch" ]]; then
        echo "No branch selected"
        return
    fi

    echo "Branch: $branch"
    echo ""

    # Check if worktree exists
    local worktree_path
    worktree_path=$(get_worktree_path "$branch")

    if [[ -d "$worktree_path" ]]; then
        echo "Worktree: $worktree_path"

        # Git status
        cd "$worktree_path" 2>/dev/null || return
        local status
        status=$(git status --porcelain 2>/dev/null)
        if [[ -z "$status" ]]; then
            echo "Status: Clean ✓"
        else
            echo "Status: Has uncommitted changes"
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
        git log --oneline --color=always -n 3 2>/dev/null | sed 's/^/  /'

    else
        echo "Worktree: Not created"
        echo ""

        # Check if branch exists locally or remotely
        if git show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
            echo "Branch type: Local"
            echo ""
            echo "Recent commits:"
            git log --oneline --color=always -n 3 "$branch" 2>/dev/null | sed 's/^/  /' || echo "  No commits yet"
        elif git ls-remote --heads origin "$branch" 2>/dev/null | grep -q "$branch"; then
            echo "Branch type: Remote only (origin/$branch)"
            echo ""
            echo "Recent commits:"
            git log --oneline --color=always -n 3 "origin/$branch" 2>/dev/null | sed 's/^/  /' || echo "  Unable to fetch commits"
        else
            # New branch - show what it will be created from
            local current_branch
            current_branch=$(git branch --show-current 2>/dev/null)
            if [[ -n "$current_branch" ]]; then
                echo "Branch type: New (will be created from '$current_branch')"
            else
                # Detached HEAD - show commit hash
                local commit_hash
                commit_hash=$(git rev-parse --short HEAD 2>/dev/null)
                echo "Branch type: New (will be created from commit $commit_hash)"
            fi
        fi
    fi
}

# Open or create worktree (called from fuzzy finder)
open_or_create_worktree() {
    local line="$1"

    # Strip ANSI color codes and extract branch name
    local branch
    branch=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[✓ ]*//' | sed 's/ \[.*\]$//')

    if [[ -z "$branch" ]]; then
        error "No branch selected"
        return 1
    fi

    local worktree_path
    worktree_path=$(get_worktree_path "$branch")

    # If worktree exists, just open it
    if [[ -d "$worktree_path" ]]; then
        info "Opening existing worktree: $worktree_path"

        if command -v cursor &> /dev/null; then
            cursor "$worktree_path"
        else
            echo -e "${BLUE}cd $worktree_path${NC}"
        fi
    else
        # Create new worktree
        cmd_add "$branch"
    fi
}

# Delete worktree (called from fuzzy finder)
delete_worktree_interactive() {
    local line="$1"

    # Strip ANSI color codes and extract branch name
    local branch
    branch=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[✓ ]*//' | sed 's/ \[.*\]$//')

    if [[ -z "$branch" ]]; then
        error "No branch selected" >&2
        return 1
    fi

    local worktree_path
    worktree_path=$(get_worktree_path "$branch")

    # Check if worktree exists
    if [[ ! -d "$worktree_path" ]]; then
        error "Worktree does not exist for branch '$branch'" >&2
        return 1
    fi

    # Check for uncommitted changes
    cd "$worktree_path" 2>/dev/null || return 1
    local status
    status=$(git status --porcelain 2>/dev/null)

    if [[ -n "$status" ]]; then
        # Has uncommitted changes - show warning and ask for confirmation
        echo "" >&2
        warning "Worktree has uncommitted changes:" >&2
        echo "$status" | head -5 >&2
        if [[ $(echo "$status" | wc -l) -gt 5 ]]; then
            echo "... and more" >&2
        fi
        echo "" >&2
        echo -n "Delete anyway? [y/N] " >&2
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Deletion cancelled" >&2
            return 1
        fi
    fi

    # Delete worktree
    if git worktree remove --force "$worktree_path" 2>/dev/null; then
        success "Deleted worktree for branch '$branch'" >&2

        # Clean up empty parent directories
        local parent_dir
        parent_dir="$(dirname "$worktree_path")"
        if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]]; then
            rmdir "$parent_dir" 2>/dev/null
        fi
    else
        error "Failed to delete worktree" >&2
        return 1
    fi
}

# Recreate worktree (delete + create fresh)
recreate_worktree() {
    local line="$1"

    # Strip ANSI color codes and extract branch name
    local branch
    branch=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[✓ ]*//' | sed 's/ \[.*\]$//')

    if [[ -z "$branch" ]]; then
        error "No branch selected" >&2
        return 1
    fi

    local worktree_path
    worktree_path=$(get_worktree_path "$branch")

    # Check if worktree exists
    if [[ ! -d "$worktree_path" ]]; then
        error "Worktree does not exist for branch '$branch'" >&2
        return 1
    fi

    # Delete first
    info "Recreating worktree for branch '$branch'..." >&2

    # Check for uncommitted changes
    cd "$worktree_path" 2>/dev/null || return 1
    local status
    status=$(git status --porcelain 2>/dev/null)

    if [[ -n "$status" ]]; then
        # Has uncommitted changes - show warning and ask for confirmation
        echo "" >&2
        warning "Worktree has uncommitted changes:" >&2
        echo "$status" | head -5 >&2
        if [[ $(echo "$status" | wc -l) -gt 5 ]]; then
            echo "... and more" >&2
        fi
        echo "" >&2
        echo -n "Recreate anyway? This will DELETE all uncommitted changes. [y/N] " >&2
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Recreate cancelled" >&2
            return 1
        fi
    fi

    # Delete worktree
    if ! git worktree remove --force "$worktree_path" 2>/dev/null; then
        error "Failed to delete worktree" >&2
        return 1
    fi

    # Clean up empty parent directories
    local parent_dir
    parent_dir="$(dirname "$worktree_path")"
    if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir" 2>/dev/null)" ]]; then
        rmdir "$parent_dir" 2>/dev/null
    fi

    success "Deleted old worktree" >&2

    # Create fresh worktree
    info "Creating fresh worktree..." >&2
    cmd_add "$branch" >&2
}

# Interactive fuzzy finder mode
cmd_interactive() {
    check_git_repo
    check_fzf

    # Check for migration notice
    check_worktree_migration

    # Start async auto-prune if enabled
    if [[ "$(git config --get worktree.autoprune 2>/dev/null)" == "true" ]]; then
        # Fork to background, redirect output to temp log
        (auto_prune_stale_worktrees > /tmp/git-wt-prune-$$.log 2>&1) &
    fi

    # Export functions so they're available to fzf subshells
    export -f show_worktree_info
    export -f open_or_create_worktree
    export -f delete_worktree_interactive
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
    export -f error
    export -f success
    export -f info
    export -f warning
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

    # Clean up FIFO on exit
    trap 'rm -f "$fifo"' EXIT

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
        --bind "d:execute-silent(delete_worktree_interactive {})+reload(generate_branch_list)" \
        --bind "r:execute-silent(recreate_worktree {})+reload(generate_branch_list)" < "$fifo")

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
            info "Cancelled"
        fi
    else
        echo ""
        info "Cancelled"
    fi
}

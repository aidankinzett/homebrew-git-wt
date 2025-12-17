#!/bin/bash

# Command implementations

# Add a new worktree
cmd_add() {
    local branch_name="$1"

    if [[ -z "$branch_name" ]]; then
        error "Branch name is required"
        echo "Usage: git-wt add <branch-name>"
        exit 1
    fi

    check_git_repo || exit 1

    # Check if branch already has a worktree (anywhere)
    if has_worktree "$branch_name"; then
        local existing_path
        existing_path=$(get_worktree_path "$branch_name")
        error "Branch '$branch_name' already has a worktree at: $existing_path"
        exit 1
    fi

    local project_name
    project_name=$(get_project_name)
    local worktree_path="$WORKTREE_BASE/$project_name/$branch_name"
    local main_worktree
    main_worktree=$(get_main_worktree)

    # Create worktree directory structure
    mkdir -p "$(dirname "$worktree_path")"

    # Fetch latest from remote to ensure we have up-to-date branch info
    info "Fetching latest from remote..."
    if git fetch origin 2>/dev/null; then
        success "Fetched latest changes from origin"
    else
        warning "Could not fetch from origin (might not have remote configured)"
    fi

    # Check if branch exists on remote
    local remote_branch_exists
    remote_branch_exists=$(git ls-remote --heads origin "$branch_name" 2>/dev/null)
    local local_branch_exists
    local_branch_exists=$(git show-ref --verify --quiet "refs/heads/$branch_name" && echo "yes" || echo "no")

    info "Creating worktree for branch '$branch_name'..."

    # Create the worktree based on what exists (check local first!)
    if [[ "$local_branch_exists" == "yes" ]]; then
        # Local branch exists - use it (most common case)
        if git worktree add "$worktree_path" "$branch_name" 2>/dev/null; then
            success "Worktree created from local branch '$branch_name'"
        else
            error "Failed to create worktree from local branch"
            exit 1
        fi
    elif [[ -n "$remote_branch_exists" ]]; then
        # Remote branch exists but no local - create local tracking remote
        if git worktree add --track -b "$branch_name" "$worktree_path" "origin/$branch_name" 2>/dev/null; then
            success "Worktree created from remote branch 'origin/$branch_name'"
        else
            error "Failed to create worktree from remote branch"
            exit 1
        fi
    else
        # Branch doesn't exist anywhere - create new branch
        if git worktree add "$worktree_path" -b "$branch_name" 2>/dev/null; then
            success "Worktree created with new branch '$branch_name'"
        else
            error "Failed to create worktree with new branch"
            exit 1
        fi
    fi

    # Symlink .env files
    symlink_env_files "$main_worktree" "$worktree_path"

    # Detect and run package manager
    local pkg_manager
    pkg_manager=$(detect_package_manager "$worktree_path")

    if [[ -n "$pkg_manager" ]]; then
        info "Detected package manager: $pkg_manager"
        info "Installing dependencies..."

        # Run in subshell to avoid changing caller's working directory
        (
            cd "$worktree_path" || { warning "Failed to change to worktree directory"; exit 1; }

            case "$pkg_manager" in
                bun)
                    if bun install; then
                        success "Dependencies installed successfully"
                    else
                        warning "Failed to install dependencies"
                    fi
                    ;;
                pnpm)
                    if pnpm install; then
                        success "Dependencies installed successfully"
                    else
                        warning "Failed to install dependencies"
                    fi
                    ;;
                yarn)
                    if yarn install; then
                        success "Dependencies installed successfully"
                    else
                        warning "Failed to install dependencies"
                    fi
                    ;;
                npm)
                    if npm install; then
                        success "Dependencies installed successfully"
                    else
                        warning "Failed to install dependencies"
                    fi
                    ;;
            esac
        )
    fi

    echo ""
    success "Worktree ready!"

    # Open in Editor
    open_in_editor "$worktree_path"
}

# List all worktrees for current project
cmd_list() {
    check_git_repo || exit 1

    # Check for migration notice
    check_worktree_migration

    local project_name
    project_name=$(get_project_name)
    local project_worktrees="$WORKTREE_BASE/$project_name"

    info "Worktrees for project '$project_name':"
    echo ""

    git worktree list | while IFS= read -r line; do
        local path
        path=$(echo "$line" | awk '{print $1}')
        local branch
        branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')
        local main_marker=""

        if echo "$line" | grep -q "(bare)"; then
            branch="(bare)"
        fi

        # Check if this is the main worktree
        if [[ "$path" == "$(get_main_worktree)" ]]; then
            main_marker="${GREEN}[main]${NC} "
        fi

        # Highlight if path is under our managed worktrees
        if [[ "$path" == "$project_worktrees"* ]]; then
            echo -e "  ${GREEN}●${NC} $main_marker$branch"
            echo -e "    ${BLUE}$path${NC}"
        else
            echo -e "  ${YELLOW}●${NC} $main_marker$branch"
            echo -e "    ${BLUE}$path${NC}"
        fi
        echo ""
    done
}

# Remove a worktree
cmd_remove() {
    local branch_name="$1"

    if [[ -z "$branch_name" ]]; then
        error "Branch name is required"
        echo "Usage: git-wt remove <branch-name>"
        exit 1
    fi

    check_git_repo || exit 1

    # Use get_worktree_path to find the actual worktree location
    # This handles cases where the directory name doesn't match the branch name
    local worktree_path
    worktree_path=$(get_worktree_path "$branch_name")

    if [[ ! -d "$worktree_path" ]]; then
        error "Worktree not found at $worktree_path"
        exit 1
    fi

    info "Removing worktree at $worktree_path..."

    if git worktree remove "$worktree_path" --force; then
        success "Worktree removed successfully"

        # Clean up empty parent directories
        local parent_dir
        parent_dir="$(dirname "$worktree_path")"
        if [[ -d "$parent_dir" ]] && [[ -z "$(ls -A "$parent_dir")" ]]; then
            rmdir "$parent_dir"
            info "Cleaned up empty directory: $parent_dir"
        fi
    else
        error "Failed to remove worktree"
        exit 1
    fi
}

# Prune stale worktree references
cmd_prune() {
    check_git_repo || exit 1

    info "Pruning stale worktree references..."

    if git worktree prune --verbose; then
        success "Pruning complete"
    else
        error "Failed to prune worktrees"
        exit 1
    fi
}

# Refresh env file symlinks in worktrees
cmd_refresh_env() {
    check_git_repo || exit 1

    # Validate argument count
    if [[ $# -gt 1 ]]; then
        error "Too many arguments. Usage: git-wt --refresh-env [branch-name]"
        echo "  git-wt --refresh-env              # Refresh all worktrees"
        echo "  git-wt --refresh-env <branch>     # Refresh specific branch"
        exit 1
    fi

    local branch_name="$1"
    local main_worktree
    main_worktree=$(git worktree list --porcelain | awk '/^worktree/ {print $2; exit}')

    if [[ -z "$main_worktree" ]]; then
        error "Could not determine main worktree path"
        exit 1
    fi

    if [[ -n "$branch_name" ]]; then
        # Refresh specific worktree - find it using git worktree list
        local worktree_path=""
        local current_path=""
        local current_branch=""

        # Parse git worktree list --porcelain to find the worktree for this branch
        while IFS= read -r line; do
            if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
                current_path="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
                current_branch="${BASH_REMATCH[1]}"
                if [[ "$current_branch" == "$branch_name" ]]; then
                    worktree_path="$current_path"
                    break
                fi
            elif [[ -z "$line" ]]; then
                # Empty line marks end of worktree entry
                current_path=""
                current_branch=""
            fi
        done < <(git worktree list --porcelain; echo "")

        if [[ -z "$worktree_path" ]]; then
            error "No worktree found for branch: $branch_name"
            exit 1
        fi

        if [[ "$worktree_path" == "$main_worktree" ]]; then
            error "Cannot refresh main worktree (it is the source of env files)"
            exit 1
        fi

        info "Refreshing env symlinks for worktree: $branch_name"
        echo ""
        if refresh_env_symlinks "$main_worktree" "$worktree_path"; then
            echo ""
            success "Env symlinks refreshed for $branch_name"
        else
            echo ""
            error "Failed to refresh env symlinks for $branch_name"
            exit 1
        fi
    else
        # Refresh all worktrees - use git worktree list as authoritative source
        info "Refreshing env symlinks for all worktrees"
        echo ""

        local refreshed_count=0
        local failed_count=0
        local current_path=""
        local current_branch=""

        # Parse git worktree list --porcelain to get all worktrees
        local current_head=""
        local is_detached=false

        while IFS= read -r line; do
            if [[ "$line" =~ ^worktree\ (.+)$ ]]; then
                current_path="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^branch\ refs/heads/(.+)$ ]]; then
                current_branch="${BASH_REMATCH[1]}"
            elif [[ "$line" =~ ^HEAD\ ([0-9a-f]+)$ ]]; then
                current_head="${BASH_REMATCH[1]}"
            elif [[ "$line" == "detached" ]]; then
                is_detached=true
            elif [[ -z "$line" ]] && [[ -n "$current_path" ]]; then
                # Empty line marks end of worktree entry - process it
                # Skip the main worktree (it's the source of truth)
                if [[ "$current_path" != "$main_worktree" ]]; then
                    # Build display name: branch or HEAD@commit for detached
                    local display_name
                    if [[ -n "$current_branch" ]]; then
                        display_name="$current_branch"
                    elif [[ "$is_detached" == true ]] && [[ -n "$current_head" ]]; then
                        display_name="HEAD@${current_head:0:7}"
                    else
                        display_name="$(basename "$current_path")"
                    fi

                    info "Processing: $display_name"
                    if refresh_env_symlinks "$main_worktree" "$current_path"; then
                        ((refreshed_count++))
                    else
                        ((failed_count++))
                    fi
                    echo ""
                fi

                # Reset for next entry
                current_path=""
                current_branch=""
                current_head=""
                is_detached=false
            fi
        done < <(git worktree list --porcelain; echo "") # Add empty line to process last entry

        if [[ $refreshed_count -eq 0 ]] && [[ $failed_count -eq 0 ]]; then
            info "No worktrees found to refresh"
        else
            success "Refreshed env symlinks for $refreshed_count worktree(s)"
            if [[ $failed_count -gt 0 ]]; then
                warning "$failed_count worktree(s) failed to refresh"
            fi
        fi
    fi
}

# Show current configuration
cmd_config() {
    info "Git Worktree Configuration"
    echo ""

    # Show current base path
    echo -e "${BLUE}Current worktree base path:${NC}"
    echo "  $WORKTREE_BASE"
    echo ""

    # Show source of configuration
    local local_config
    local global_config
    local env_var="$GIT_WT_BASE"
    local_config=$(git config --local --get worktree.basepath 2>/dev/null)
    global_config=$(git config --global --get worktree.basepath 2>/dev/null)

    echo -e "${BLUE}Configuration sources (in priority order):${NC}"

    if [[ -n "$local_config" ]]; then
        echo -e "  ${GREEN}✓${NC} Local git config:  $local_config ${GREEN}[active]${NC}"
    else
        echo -e "    Local git config:  ${YELLOW}(not set)${NC}"
    fi

    if [[ -n "$global_config" ]]; then
        if [[ -z "$local_config" ]]; then
            echo -e "  ${GREEN}✓${NC} Global git config: $global_config ${GREEN}[active]${NC}"
        else
            echo -e "    Global git config: $global_config ${YELLOW}(overridden by local)${NC}"
        fi
    else
        echo -e "    Global git config: ${YELLOW}(not set)${NC}"
    fi

    if [[ -n "$env_var" ]]; then
        if [[ -z "$local_config" ]] && [[ -z "$global_config" ]]; then
            echo -e "  ${GREEN}✓${NC} Environment var:   $env_var ${GREEN}[active]${NC}"
        else
            echo -e "    Environment var:   $env_var ${YELLOW}(overridden)${NC}"
        fi
    else
        echo -e "    Environment var:   ${YELLOW}(not set)${NC}"
    fi

    if [[ -z "$local_config" ]] && [[ -z "$global_config" ]] && [[ -z "$env_var" ]]; then
        echo -e "  ${GREEN}✓${NC} Default:           $HOME/Git/.worktrees ${GREEN}[active]${NC}"
    else
        echo -e "    Default:           $HOME/Git/.worktrees"
    fi

    echo ""

    # Show auto-prune status
    local autoprune
    autoprune=$(git config --get worktree.autoprune 2>/dev/null)
    echo -e "${BLUE}Auto-pruning:${NC}"
    if [[ "$autoprune" == "true" ]]; then
        echo -e "  ${GREEN}✓ Enabled${NC}"
    else
        echo -e "  ${YELLOW}✗ Disabled${NC}"
    fi

    echo ""
    # Show editor configuration
    local editor
    editor=$(git config --get worktree.editor 2>/dev/null)
    echo -e "${BLUE}Editor:${NC}"
    if [[ -n "$editor" ]]; then
        echo -e "  ${GREEN}✓ Configured: $editor${NC}"
    else
        local detected
        detected=$(get_editor)
        if [[ -n "$detected" ]]; then
            echo -e "  ${GREEN}✓ Detected: $detected (default)${NC}"
        else
            echo -e "  ${YELLOW}✗ No supported editor found${NC}"
        fi
    fi

    echo ""
    info "To change configuration:"
    echo "  git config --global worktree.basepath <path>  # Set globally"
    echo "  git config --local worktree.basepath <path>   # Set for this repo"
    echo "  export GIT_WT_BASE=<path>                     # Set via environment"
    echo "  git config --global worktree.editor <editor>  # Set editor (code, cursor, agy)"
}

# Show help
cmd_help() {
    cat << EOF
git-wt - Git worktree management tool

USAGE:
  git-wt [branch-name|options]

MODES:
  git-wt                Interactive fuzzy finder to browse and select branches
                        - Shows all local and remote branches
                        - Visual indicators for existing worktrees
                        - Preview pane with worktree details
                        - Press Enter to create or open worktree

  git-wt <branch-name>  Directly create or open worktree for specified branch
                        - Creates worktree at ${WORKTREE_BASE}/<project>/<branch>
                        - Symlinks all .env* files from main repo
                        - Detects and runs package manager install
                        - Opens in Cursor (if available)

OPTIONS:
  --list, -l               Show all worktrees for the current project
  --remove <branch>, -r    Remove a worktree
  --prune, -p              Remove stale worktree references
  --cleanup                Manually prune merged branch worktrees
  --refresh-env [branch]   Refresh env file symlinks (all worktrees or specific branch)
  --enable-autoprune       Enable automatic pruning for this repo
  --disable-autoprune      Disable automatic pruning for this repo
  --config                 Show current configuration
  --help, -h               Show this help message

EXAMPLES:
  # Launch interactive fuzzy finder
  git-wt

  # Directly create/open a worktree
  git-wt feature/new-feature

  # List all worktrees
  git-wt --list

  # Remove a worktree
  git-wt --remove feature/old-feature

  # Clean up stale references
  git-wt --prune

  # Enable auto-pruning (removes merged branches automatically)
  git-wt --enable-autoprune

  # Manually cleanup merged branch worktrees
  git-wt --cleanup

  # Refresh env symlinks in all worktrees
  git-wt --refresh-env

  # Refresh env symlinks in a specific worktree
  git-wt --refresh-env feature/my-branch

  # Show current configuration
  git-wt --config

AUTO-PRUNING:
  When enabled, git-wt automatically removes worktrees for branches that have been
  merged into main/master. This happens in the background when running git-wt.

  Safety: Only removes worktrees with no uncommitted changes.

  Enable:  git-wt --enable-autoprune
  Disable: git-wt --disable-autoprune
  Manual:  git-wt --cleanup

LOCATION:
  All worktrees are stored in: ${WORKTREE_BASE}/<project-name>/<branch-name>

CONFIGURATION:
  You can customize the worktree storage location:

  # Set globally for all repositories
  git config --global worktree.basepath ~/custom/path

  # Set for current repository only
  git config --local worktree.basepath ~/custom/path

  # Or use environment variable
  export GIT_WT_BASE=~/custom/path

  Priority: local git config > global git config > environment variable > default

REQUIREMENTS:
  - fzf (for interactive mode): brew install fzf

EOF
}

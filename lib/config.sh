#!/bin/bash

# Configuration management functions

# Check if user has completed onboarding
is_onboarded() {
    local onboarded
    onboarded=$(git config --local --get worktree.onboarded 2>/dev/null)
    [[ "$onboarded" == "true" ]]
}

# Run onboarding flow
run_onboarding() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Welcome to git-wt!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "Let's set up git-wt for this repository."
    echo ""

    # Ask about worktree location
    echo -e "${BLUE}Worktree Storage Location${NC}"
    echo "All worktrees will be stored at: <base-path>/<project-name>/<branch-name>"
    echo ""
    echo -e "Default location: ${GREEN}~/.worktrees${NC}"
    echo ""
    read -r -p "Press Enter to use default, or type a custom path: " custom_path
    echo ""

    local base_path
    if [[ -n "$custom_path" ]]; then
        # Expand tilde if present
        base_path="${custom_path/#\~/$HOME}"

        # Validate the path
        if [[ ! "$base_path" =~ ^/ ]]; then
            # Not an absolute path, make it relative to HOME
            base_path="$HOME/$base_path"
        fi

        # Create directory if it doesn't exist
        if [[ ! -d "$base_path" ]]; then
            if mkdir -p "$base_path" 2>/dev/null; then
                success "Created directory: $base_path"
            else
                error "Failed to create directory: $base_path"
                warning "Falling back to default: ~/.worktrees"
                base_path="$HOME/.worktrees"
            fi
        fi

        # Save to local git config
        git config --local worktree.basepath "$base_path"
        success "Worktree location set to: $base_path"
    else
        success "Using default location: ~/.worktrees"
    fi
    echo ""

    # Ask about auto-pruning
    echo -e "${BLUE}Auto-Pruning${NC}"
    echo "git-wt can automatically clean up worktrees for branches that have been"
    echo "merged into main/master. This keeps your workspace tidy."
    echo ""
    echo "Safety: Only removes worktrees with no uncommitted changes."
    echo ""
    read -r -p "Enable auto-pruning? (y/N): " enable_autoprune
    echo ""

    if [[ "$enable_autoprune" =~ ^[Yy]$ ]]; then
        git config --local worktree.autoprune true
        success "Auto-pruning enabled"
    else
        info "Auto-pruning disabled (you can enable it later with: git-wt --enable-autoprune)"
    fi
    echo ""

    # Mark as onboarded
    git config --local worktree.onboarded true

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}Setup complete!${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "You're all set! Try running:"
    echo -e "  ${BLUE}git-wt${NC}                  # Launch interactive fuzzy finder"
    echo -e "  ${BLUE}git-wt <branch-name>${NC}    # Create/open a worktree"
    echo -e "  ${BLUE}git-wt --help${NC}           # See all available commands"
    echo ""
}

# Get base directory for all worktrees
# Priority: local git config > global git config > environment variable > default
get_worktree_base() {
    local base_path
    local validated_path

    # Try local git config first
    base_path=$(git config --local --get worktree.basepath 2>/dev/null)
    if [[ -n "$base_path" ]]; then
        if validated_path=$(validate_worktree_path "$base_path" "local git config"); then
            echo "$validated_path"
            return
        fi
        # Invalid config - fall through to next option
        warning "Falling back to next configuration option..."
        echo "" >&2  # Add blank line for readability
    fi

    # Try global git config
    base_path=$(git config --global --get worktree.basepath 2>/dev/null)
    if [[ -n "$base_path" ]]; then
        if validated_path=$(validate_worktree_path "$base_path" "global git config"); then
            echo "$validated_path"
            return
        fi
        # Invalid config - fall through to next option
        warning "Falling back to next configuration option..."
        echo "" >&2  # Add blank line for readability
    fi

    # Try environment variable
    if [[ -n "$GIT_WT_BASE" ]]; then
        if validated_path=$(validate_worktree_path "$GIT_WT_BASE" "environment variable GIT_WT_BASE"); then
            echo "$validated_path"
            return
        fi
        # Invalid config - fall through to default
        warning "Falling back to default path..."
        echo "" >&2  # Add blank line for readability
    fi

    # Default
    echo "$HOME/.worktrees"
}

# Check for worktrees in different locations and warn about migration
check_worktree_migration() {
    local project_name
    project_name=$(get_project_name 2>/dev/null)

    # Only check if we can get the project name (we're in a git repo)
    if [[ -z "$project_name" ]]; then
        return
    fi

    local current_base="$WORKTREE_BASE"
    local found_elsewhere=false
    local other_locations=()

    # Check all possible configuration sources for different paths
    local local_config
    local global_config
    local env_var="$GIT_WT_BASE"
    local_config=$(git config --local --get worktree.basepath 2>/dev/null)
    global_config=$(git config --global --get worktree.basepath 2>/dev/null)
    local default_path="$HOME/.worktrees"

    # Build list of paths to check (excluding the current one)
    # Expand tildes and deduplicate paths
    local paths_to_check=()
    local seen_paths=()

    # Helper to add path if unique and different from current
    add_if_unique() {
        local path="$1"
        # Only expand tilde if path isn't already absolute (avoid double expansion)
        if [[ "$path" == "~"* ]]; then
            path="${path/#\~/$HOME}"
        fi

        # Skip if it's the current base (which is already expanded)
        if [[ "$path" == "$current_base" ]]; then
            return
        fi

        # Check if already seen (safe for empty array)
        local seen_path
        for seen_path in "${seen_paths[@]}"; do
            if [[ "$seen_path" == "$path" ]]; then
                return
            fi
        done

        # Add to both arrays
        paths_to_check+=("$path")
        seen_paths+=("$path")
    }

    [[ -n "$local_config" ]] && add_if_unique "$local_config"
    [[ -n "$global_config" ]] && add_if_unique "$global_config"
    [[ -n "$env_var" ]] && add_if_unique "$env_var"
    add_if_unique "$default_path"

    # Check if worktrees exist in other locations
    for check_path in "${paths_to_check[@]}"; do
        local project_dir="$check_path/$project_name"
        if [[ -d "$project_dir" ]] && [[ -n "$(ls -A "$project_dir" 2>/dev/null)" ]]; then
            found_elsewhere=true
            other_locations+=("$project_dir")
        fi
    done

    # Show migration warning if worktrees found elsewhere
    if [[ "$found_elsewhere" == "true" ]]; then
        echo "" >&2
        warning "Migration Notice: Existing worktrees found in different location(s):"
        for location in "${other_locations[@]}"; do
            echo -e "  ${YELLOW}•${NC} $location" >&2
        done
        echo "" >&2
        info "Current worktree base: $current_base" >&2
        info "Existing worktrees in the old location(s) won't be detected by git-wt." >&2
        info "You may want to move them to the new location or adjust your configuration." >&2
        echo "" >&2
    fi
}

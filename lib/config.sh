#!/bin/bash

# Configuration management functions

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
		echo "" >&2 # Add blank line for readability
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
		echo "" >&2 # Add blank line for readability
	fi

	# Try environment variable
	if [[ -n "$GIT_WT_BASE" ]]; then
		if validated_path=$(validate_worktree_path "$GIT_WT_BASE" "environment variable GIT_WT_BASE"); then
			echo "$validated_path"
			return
		fi
		# Invalid config - fall through to default
		warning "Falling back to default path..."
		echo "" >&2 # Add blank line for readability
	fi

	# Default
	echo "$HOME/Git/.worktrees"
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
	local default_path="$HOME/Git/.worktrees"

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

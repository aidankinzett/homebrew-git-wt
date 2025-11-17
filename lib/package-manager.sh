#!/bin/bash

# Package manager detection and environment file management
#
# Prerequisites:
#   - Expected helper functions (provided by the calling environment):
#     * info()    - Log informational messages
#     * warning() - Log warning messages
#     * success() - Log success messages
#   - These are typically sourced from lib/colors.sh

# Detect package manager
detect_package_manager() {
	local worktree_path="$1"

	if [[ -f "$worktree_path/pnpm-lock.yaml" ]]; then
		echo "pnpm"
	elif [[ -f "$worktree_path/yarn.lock" ]]; then
		echo "yarn"
	elif [[ -f "$worktree_path/package-lock.json" ]]; then
		echo "npm"
	else
		# Default to pnpm if no lock file found but package.json exists
		if [[ -f "$worktree_path/package.json" ]]; then
			echo "pnpm"
		else
			echo ""
		fi
	fi
}

# Symlink env files
symlink_env_files() {
	local source_dir="$1"
	local target_dir="$2"

	local env_files
	env_files=$(find "$source_dir" -maxdepth 1 -type f \( -name ".env" -o -name ".env.*" \) 2>/dev/null)

	if [[ -z "$env_files" ]]; then
		info "No .env files found to symlink"
		return
	fi

	info "Symlinking .env files..."
	while IFS= read -r env_file; do
		if [[ -n "$env_file" ]]; then
			local filename
			filename=$(basename "$env_file")
			local target="$target_dir/$filename"

			# Resolve to absolute path to avoid broken relative symlinks
			local abs_env_file
			if command -v realpath &>/dev/null; then
				abs_env_file=$(realpath "$env_file" 2>/dev/null)
			elif command -v readlink &>/dev/null; then
				abs_env_file=$(readlink -f "$env_file" 2>/dev/null)
			else
				# Fallback: assume find already returned absolute paths from source_dir
				abs_env_file="$env_file"
			fi

			if [[ ! -f "$abs_env_file" ]]; then
				warning "Could not resolve absolute path for $filename, skipping"
				continue
			fi

			if [[ -e "$target" ]]; then
				warning "Skipping $filename (already exists in worktree)"
			else
				if ln -s "$abs_env_file" "$target" 2>/dev/null; then
					success "  Linked $filename"
				else
					warning "Failed to create symlink for $filename"
				fi
			fi
		fi
	done <<<"$env_files"
}

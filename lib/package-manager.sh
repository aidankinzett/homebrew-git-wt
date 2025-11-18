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
            if command -v realpath &> /dev/null; then
                abs_env_file=$(realpath "$env_file" 2>/dev/null)
            elif command -v readlink &> /dev/null; then
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
    done <<< "$env_files"
}

# Refresh env file symlinks in an existing worktree
# This removes old/stale env symlinks and creates new ones based on current base repo
refresh_env_symlinks() {
    local source_dir="$1"
    local target_dir="$2"

    if [[ ! -d "$target_dir" ]]; then
        error "Target directory does not exist: $target_dir"
        return 1
    fi

    # Find and remove existing env symlinks in the target directory
    local removed_count=0
    while IFS= read -r symlink; do
        if [[ -n "$symlink" && -L "$symlink" ]]; then
            local filename
            filename=$(basename "$symlink")
            if rm "$symlink" 2>/dev/null; then
                info "Removed old symlink: $filename"
                ((removed_count++))
            else
                warning "Failed to remove symlink: $filename"
            fi
        fi
    done < <(find "$target_dir" -maxdepth 1 -type l \( -name ".env" -o -name ".env.*" \) 2>/dev/null)

    if [[ $removed_count -eq 0 ]]; then
        info "No existing env symlinks found to remove"
    fi

    # Create new symlinks from source
    local env_files
    env_files=$(find "$source_dir" -maxdepth 1 -type f \( -name ".env" -o -name ".env.*" \) 2>/dev/null)

    if [[ -z "$env_files" ]]; then
        info "No .env files found in base repo to symlink"
        return 0
    fi

    info "Creating new env symlinks..."
    local created_count=0
    while IFS= read -r env_file; do
        if [[ -n "$env_file" ]]; then
            local filename
            filename=$(basename "$env_file")
            local target="$target_dir/$filename"

            # Resolve to absolute path to avoid broken relative symlinks
            local abs_env_file
            if command -v realpath &> /dev/null; then
                abs_env_file=$(realpath "$env_file" 2>/dev/null)
            elif command -v readlink &> /dev/null; then
                abs_env_file=$(readlink -f "$env_file" 2>/dev/null)
            else
                abs_env_file="$env_file"
            fi

            if [[ ! -f "$abs_env_file" ]]; then
                warning "Could not resolve absolute path for $filename, skipping"
                continue
            fi

            # Check if a regular file (not symlink) exists - don't overwrite
            if [[ -f "$target" && ! -L "$target" ]]; then
                warning "Skipping $filename (regular file exists, not a symlink)"
            else
                # Remove if it exists (broken symlink or regular symlink)
                [[ -e "$target" || -L "$target" ]] && rm "$target" 2>/dev/null

                if ln -s "$abs_env_file" "$target" 2>/dev/null; then
                    success "  Linked $filename"
                    ((created_count++))
                else
                    warning "Failed to create symlink for $filename"
                fi
            fi
        fi
    done <<< "$env_files"

    if [[ $created_count -eq 0 ]]; then
        warning "No new env symlinks were created"
    else
        success "Created $created_count env symlink(s)"
    fi
}

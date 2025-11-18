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

# Resolve a path to its absolute form
# Tries realpath first (GNU), then readlink (BSD), then returns as-is
# Args:
#   $1 - path to resolve
# Returns:
#   Absolute path on success, original path on failure
resolve_absolute_path() {
    local path="$1"

    if command -v realpath &> /dev/null; then
        realpath "$path" 2>/dev/null || echo "$path"
    elif command -v readlink &> /dev/null; then
        readlink -f "$path" 2>/dev/null || echo "$path"
    else
        echo "$path"
    fi
}

# Symlink environment files from source to target directory
#
# Creates symlinks for all .env and .env.* files found in the source directory.
# Skips files that already exist in the target directory.
#
# Args:
#   $1 - source_dir: Directory containing .env files to symlink from (typically main worktree)
#   $2 - target_dir: Directory to create symlinks in (typically a worktree)
#
# Returns:
#   0 on success, non-zero on failure
#
# Examples:
#   symlink_env_files "$main_worktree" "$new_worktree"
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

            local abs_env_file
            abs_env_file=$(resolve_absolute_path "$env_file")

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

# Refresh environment file symlinks in an existing worktree
#
# Updates symlinks in a worktree to match the current .env files in the main worktree.
# This is useful when .env files are renamed, added, or removed in the main worktree.
#
# Process:
#   1. Validates target directory exists
#   2. Removes all existing .env* symlinks from target
#   3. Creates new symlinks for all .env* files found in source
#   4. Validates symlink targets are within source directory (security)
#   5. Preserves regular files (non-symlinks) in target directory
#
# Args:
#   $1 - source_dir: Directory containing .env files (typically main worktree)
#   $2 - target_dir: Worktree directory to update symlinks in
#
# Returns:
#   0 on success, 1 on failure
#
# Examples:
#   # Refresh after renaming .env to .env.local
#   refresh_env_symlinks "$main_worktree" "$feature_worktree"
#
# Security:
#   - Only creates symlinks to files within source_dir
#   - Preserves regular files (won't overwrite user's custom .env files)
refresh_env_symlinks() {
    local source_dir="$1"
    local target_dir="$2"

    # Validate target directory exists
    if [[ ! -d "$target_dir" ]]; then
        error "Target directory does not exist: $target_dir"
        return 1
    fi

    # Resolve source directory to absolute path once
    local abs_source_dir
    abs_source_dir=$(resolve_absolute_path "$source_dir")

    # Track old symlinks for informative messages
    local old_symlinks=()
    while IFS= read -r symlink; do
        if [[ -n "$symlink" ]]; then
            old_symlinks+=("$(basename "$symlink")")
        fi
    done < <(find "$target_dir" -maxdepth 1 -type l \( -name ".env" -o -name ".env.*" \) 2>/dev/null)

    # Remove existing env symlinks in the target directory
    local removed_count=0
    for symlink_name in "${old_symlinks[@]}"; do
        local symlink_path="$target_dir/$symlink_name"
        if rm "$symlink_path" 2>/dev/null; then
            info "  Removed: $symlink_name"
            ((removed_count++))
        else
            warning "  Failed to remove: $symlink_name"
        fi
    done

    if [[ $removed_count -eq 0 ]]; then
        info "No existing env symlinks to remove"
    else
        info "Removed $removed_count old symlink(s)"
    fi

    # Find new env files in source
    local env_files
    env_files=$(find "$source_dir" -maxdepth 1 -type f \( -name ".env" -o -name ".env.*" \) 2>/dev/null)

    if [[ -z "$env_files" ]]; then
        info "No .env files found in source to symlink"
        return 0
    fi

    # Create new symlinks from source
    info "Creating new symlinks..."
    local created_count=0
    local new_files=()

    while IFS= read -r env_file; do
        if [[ -n "$env_file" ]]; then
            local filename
            filename=$(basename "$env_file")
            local target="$target_dir/$filename"

            # Resolve to absolute path
            local abs_env_file
            abs_env_file=$(resolve_absolute_path "$env_file")

            if [[ ! -f "$abs_env_file" ]]; then
                warning "  Could not resolve: $filename"
                continue
            fi

            # Security: Validate symlink target is within source directory
            if [[ "$abs_env_file" != "$abs_source_dir"/* ]] && [[ "$abs_env_file" != "$abs_source_dir" ]]; then
                warning "  Skipped: $filename (outside source directory)"
                continue
            fi

            # Check if a regular file (not symlink) exists - don't overwrite
            if [[ -f "$target" && ! -L "$target" ]]; then
                warning "  Skipped: $filename (regular file exists)"
            else
                # Atomic symlink update: create temp symlink then rename
                # This avoids race condition window between rm and ln
                local temp_target="$target.tmp.$$"

                if ln -s "$abs_env_file" "$temp_target" 2>/dev/null; then
                    # Atomically replace old symlink with new one
                    if mv -f "$temp_target" "$target" 2>/dev/null; then
                        new_files+=("$filename")
                        ((created_count++))
                    else
                        warning "  Failed to update: $filename"
                        rm -f "$temp_target" 2>/dev/null
                    fi
                else
                    warning "  Failed to create symlink: $filename"
                fi
            fi
        fi
    done <<< "$env_files"

    # Show informative summary of changes
    if [[ $created_count -eq 0 ]]; then
        warning "No new symlinks created"
        return 0
    fi

    # Display what changed
    for new_file in "${new_files[@]}"; do
        success "  Linked: $new_file"
    done

    # Show helpful summary if files were renamed
    if [[ $removed_count -gt 0 ]] && [[ $created_count -gt 0 ]]; then
        if [[ $removed_count -eq 1 ]] && [[ $created_count -eq 1 ]]; then
            info "Updated: ${old_symlinks[0]} → ${new_files[0]}"
        else
            info "Updated: $removed_count removed, $created_count created"
        fi
    else
        success "Created $created_count new symlink(s)"
    fi
}

#!/bin/bash

# Package manager detection and environment file management

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

            if [[ -e "$target" ]]; then
                warning "Skipping $filename (already exists in worktree)"
            else
                ln -s "$env_file" "$target"
                success "  Linked $filename"
            fi
        fi
    done <<< "$env_files"
}

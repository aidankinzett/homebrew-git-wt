#!/bin/bash

# Path validation functions

# Validate and sanitize a path for use as worktree base
validate_worktree_path() {
    local path="$1"
    local source="$2"  # For error messages: "local config", "global config", "environment variable"

    # Expand tilde
    path="${path/#\~/$HOME}"

    # Check for dangerous characters including control characters and newlines
    local dangerous_pattern='[;|&$`[:cntrl:]]'
    if [[ "$path" =~ $dangerous_pattern ]]; then
        warning "Invalid path in $source: contains dangerous characters"
        warning "Path should not contain: ; | & \$ \` or control characters"
        return 1
    fi

    # Check if path is absolute
    if [[ "$path" != /* ]]; then
        warning "Invalid path in $source: must be an absolute path"
        warning "Got: $path"
        warning "Expected path starting with /"
        return 1
    fi

    # Normalize path by removing trailing slashes
    path="${path%/}"

    # Canonicalize the path to resolve '..' and prevent path traversal
    # Use -m to allow non-existent paths (won't create them)
    if command -v realpath &> /dev/null; then
        local canonicalized
        if canonicalized=$(realpath -m "$path" 2>/dev/null); then
            path="$canonicalized"
        else
            warning "realpath command failed - falling back to basic normalization"
            warning "Install 'coreutils' (brew install coreutils) for improved path safety"
            path=$(echo "$path" | sed 's#/\+#/#g' | sed 's#/$##')
        fi
    else
        warning "realpath command not found - path traversal protection is limited"
        warning "Install 'coreutils' (brew install coreutils) for improved path safety"
        path=$(echo "$path" | sed 's#/\+#/#g' | sed 's#/$##')
    fi

    echo "$path"
    return 0
}

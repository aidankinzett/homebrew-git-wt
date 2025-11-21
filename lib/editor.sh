#!/bin/bash

# Editor resolution and opening functions

# List of allowed editors for security
# Only these editors will be automatically executed
ALLOWED_EDITORS=("code" "cursor" "vim" "vi" "nano" "emacs" "nvim" "subl" "mate" "atom")

# Get the configured editor
# Priority:
# 1. GIT_WT_EDITOR_OVERRIDE (from --editor flag)
# 2. git config worktree.editor
# 3. VISUAL environment variable
# 4. EDITOR environment variable
# 5. VS Code (code) if available
# 6. Cursor (cursor) if available
get_editor() {
    # 1. Check override (flag)
    if [[ -n "$GIT_WT_EDITOR_OVERRIDE" ]]; then
        echo "$GIT_WT_EDITOR_OVERRIDE"
        return 0
    fi

    # 2. Check git config
    local config_editor
    config_editor=$(git config --get worktree.editor 2>/dev/null)
    if [[ -n "$config_editor" ]]; then
        echo "$config_editor"
        return 0
    fi

    # 3. Check VISUAL
    if [[ -n "$VISUAL" ]]; then
        echo "$VISUAL"
        return 0
    fi

    # 4. Check EDITOR
    if [[ -n "$EDITOR" ]]; then
        echo "$EDITOR"
        return 0
    fi

    # 5. Default: Try VS Code
    if command -v code &> /dev/null; then
        echo "code"
        return 0
    fi

    # 6. Default: Try Cursor
    if command -v cursor &> /dev/null; then
        echo "cursor"
        return 0
    fi

    # No editor found
    return 1
}

# Check if an editor command is allowed
# Arguments:
#   $1: The editor command (first word)
is_allowed_editor() {
    local cmd="$1"
    local allowed
    for allowed in "${ALLOWED_EDITORS[@]}"; do
        if [[ "$cmd" == "$allowed" ]]; then
            return 0
        fi
    done
    return 1
}

# Open a worktree in the resolved editor
# Arguments:
#   $1: Path to the worktree
open_in_editor() {
    local worktree_path="$1"
    local editor

    # Default fallback message function
    print_fallback() {
        info "To switch to the new worktree, run:"
        echo -e "${BLUE}  cd $worktree_path${NC}"
    }

    if editor=$(get_editor); then
        # Use array-based parsing for safer word splitting
        local editor_cmd
        read -r -a editor_cmd <<< "$editor"
        local base_cmd="${editor_cmd[0]}"

        # Security: Check against allowlist FIRST
        if ! is_allowed_editor "$base_cmd"; then
            warning "Editor '$base_cmd' is not in the allowlist. Skipping automatic open."
            info "Allowed editors: ${ALLOWED_EDITORS[*]}"
            print_fallback
            return 1
        fi

        # Security: Validate the base command exists
        if ! command -v "$base_cmd" &> /dev/null; then
            warning "Editor command '$base_cmd' not found."
            print_fallback
            return 1
        fi

        info "Opening worktree in $editor..."

        # Execute with error handling
        if ! "${editor_cmd[@]}" "$worktree_path"; then
            warning "Failed to open editor."
            print_fallback
            return 1
        fi
    else
        print_fallback
    fi
}

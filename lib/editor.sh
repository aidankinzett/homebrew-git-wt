#!/bin/bash

# Editor resolution and opening functions

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

# Open a worktree in the resolved editor
# Arguments:
#   $1: Path to the worktree
open_in_editor() {
    local worktree_path="$1"
    local editor

    if editor=$(get_editor); then
        info "Opening worktree in $editor..."

        # Use word splitting to handle arguments in editor command (e.g. "code -n")
        # shellcheck disable=SC2086
        $editor "$worktree_path"
    else
        info "To switch to the new worktree, run:"
        echo -e "${BLUE}  cd $worktree_path${NC}"
    fi
}

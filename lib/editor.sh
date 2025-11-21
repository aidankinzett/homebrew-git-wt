#!/bin/bash

# Editor resolution and opening functions

# Get the configured editor
# Priority:
# 1. git config worktree.editor (if valid)
# 2. Automatic detection (cursor, code, agy)
get_editor() {
    local configured_editor
    configured_editor=$(git config --get worktree.editor 2>/dev/null)

    # If configured, validate it
    if [[ -n "$configured_editor" ]]; then
        case "$configured_editor" in
            code|cursor|agy)
                if command -v "$configured_editor" &> /dev/null; then
                    echo "$configured_editor"
                    return 0
                else
                    # Only warn if we are going to fall back
                    # But wait, get_editor is usually called in a subshell or assignment,
                    # so warnings should go to stderr
                    warning "Configured editor '$configured_editor' not found in PATH" >&2
                fi
                ;;
            *)
                warning "Invalid editor configured: $configured_editor" >&2
                warning "Allowed options: code, cursor, agy" >&2
                ;;
        esac
    fi

    # Fallback: Automatic detection
    # Prioritize Cursor as per original behavior, then Code, then Agy
    if command -v cursor &> /dev/null; then
        echo "cursor"
        return 0
    elif command -v code &> /dev/null; then
        echo "code"
        return 0
    elif command -v agy &> /dev/null; then
        echo "agy"
        return 0
    fi

    return 1
}

# Open the worktree in the resolved editor
open_in_editor() {
    local path="$1"
    local editor

    editor=$(get_editor)

    if [[ -n "$editor" ]]; then
        info "Opening worktree in $editor..."
        "$editor" "$path"
    else
        # No supported editor found
        info "To switch to the new worktree, run:"
        echo -e "${BLUE}  cd $path${NC}"
    fi
}

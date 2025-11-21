# Test helper functions and setup

# Setup test environment
setup_test_git_repo() {
    export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    TEST_TEMP_DIR="$(mktemp -d)"
    export TEST_TEMP_DIR
    cd "$TEST_TEMP_DIR" || return

    export HOME="$TEST_TEMP_DIR/home"
    mkdir -p "$HOME"

    git init
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Disable commit signing for tests
    git config commit.gpgsign false
    git config tag.gpgsign false

    # Create initial commit
    echo "# Test Repo" > README.md
    git add README.md
    git commit -m "Initial commit"
}

# Teardown test environment
teardown_test_git_repo() {
    if [[ -n "$TEST_TEMP_DIR" ]] && [[ -d "$TEST_TEMP_DIR" ]]; then
        # Validate that TEST_TEMP_DIR is inside expected temp directories before removing
        # This prevents accidental deletion if mktemp fails or returns an unexpected path
        # Linux: /tmp/*
        # macOS: /var/folders/*/T/*
        case "$TEST_TEMP_DIR" in
            /tmp/*|/var/folders/*/T/*)
                rm -rf "$TEST_TEMP_DIR"
                ;;
            *)
                echo "Warning: TEST_TEMP_DIR ($TEST_TEMP_DIR) is not in expected temp location, skipping cleanup" >&2
                ;;
        esac
    fi
}

# Load git-wt script functions for testing
load_git_wt() {
    # Set up FZF mocking files
    export FZF_OUTPUT_FILE="$TEST_TEMP_DIR/fzf_output"
    export FZF_ARGS_FILE="$TEST_TEMP_DIR/fzf_args"
    
    # Mock fzf function that reads from FZF_OUTPUT_FILE and logs args to FZF_ARGS_FILE
    # shellcheck disable=SC2317,SC2329
    function fzf() {
        # Log all arguments to file for test verification
        echo "$@" > "$FZF_ARGS_FILE"
        
        # Read the mocked output if file exists
        if [[ -f "$FZF_OUTPUT_FILE" ]]; then
            cat "$FZF_OUTPUT_FILE"
            return 0
        else
            # If no mock file, simulate cancellation (Esc pressed)
            return 1
        fi
    }
    export -f fzf
    
    # Source the main script to make functions available
    # shellcheck disable=SC1091
    source "$BATS_TEST_DIRNAME/../git-wt"
}

# Canonicalize a path the same way validate_worktree_path does
canonicalize_path() {
    local path="$1"
    # Use grealpath if available (GNU coreutils), otherwise use realpath or return as-is
    if command -v grealpath &> /dev/null; then
        grealpath -m "$path" 2>/dev/null || echo "$path"
    elif command -v realpath &> /dev/null; then
        realpath -m "$path" 2>/dev/null || echo "$path"
    else
        echo "$path"
    fi
}

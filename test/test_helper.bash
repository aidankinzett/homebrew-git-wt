# Test helper functions and setup

# Setup test environment
setup_test_git_repo() {
    export TEST_TEMP_DIR="$(mktemp -d)"
    cd "$TEST_TEMP_DIR"

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
        # Validate that TEST_TEMP_DIR is inside /tmp before removing
        # This prevents accidental deletion if mktemp fails or returns an unexpected path
        case "$TEST_TEMP_DIR" in
            /tmp/*)
                rm -rf "$TEST_TEMP_DIR"
                ;;
            *)
                echo "Warning: TEST_TEMP_DIR ($TEST_TEMP_DIR) is not in /tmp, skipping cleanup" >&2
                ;;
        esac
    fi
}

# Load git-wt script functions for testing
load_git_wt() {
    # Source the main script to make functions available
    source "$BATS_TEST_DIRNAME/../git-wt"
}

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
	echo "# Test Repo" >README.md
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
		/tmp/* | /var/folders/*/T/*)
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
	# Source the main script to make functions available
	# shellcheck disable=SC1091
	source "$BATS_TEST_DIRNAME/../git-wt"
}

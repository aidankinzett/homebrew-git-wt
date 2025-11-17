#!/bin/bash

# Path validation functions

# Helper: Normalize path by collapsing multiple slashes and removing trailing slashes
# Preserves root "/" as-is
_normalize_path() {
	local path="$1"
	# Collapse multiple slashes and remove trailing slash
	path=$(echo "$path" | sed 's#/\+#/#g' | sed 's#/$##')
	# Special case: preserve root path "/"
	if [[ -z "$path" ]]; then
		echo "/"
	else
		echo "$path"
	fi
}

# Validate and sanitize a path for use as worktree base
validate_worktree_path() {
	local path="$1"
	local source="$2" # For error messages: "local config", "global config", "environment variable"

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

	# Canonicalize the path to resolve '..' and prevent path traversal
	# Use -m to allow non-existent paths (won't create them)
	# Try GNU realpath first (grealpath on macOS with coreutils), then fall back to BSD realpath
	local realpath_cmd
	if command -v grealpath &>/dev/null; then
		realpath_cmd="grealpath"
	elif command -v realpath &>/dev/null; then
		realpath_cmd="realpath"
	fi

	if [[ -n "$realpath_cmd" ]]; then
		local canonicalized
		if canonicalized=$("$realpath_cmd" -m "$path" 2>/dev/null); then
			path="$canonicalized"
		else
			path=$(_normalize_path "$path")
		fi
	else
		path=$(_normalize_path "$path")
	fi

	echo "$path"
	return 0
}

#!/usr/bin/env bats

# Tests for get_project_name function

load test_helper

setup() {
	setup_test_git_repo
	load_git_wt
}

teardown() {
	teardown_test_git_repo
}

@test "get_project_name extracts name from HTTPS remote URL" {
	git remote add origin https://github.com/aidankinzett/homebrew-git-wt.git

	result=$(get_project_name)

	[ "$result" = "homebrew-git-wt" ]
}

@test "get_project_name extracts name from SSH remote URL" {
	git remote add origin git@github.com:aidankinzett/homebrew-git-wt.git

	result=$(get_project_name)

	[ "$result" = "homebrew-git-wt" ]
}

@test "get_project_name falls back to directory name when no remote" {
	# No remote configured, should use directory basename
	result=$(get_project_name)

	# The temp directory name will be the project name
	expected=$(basename "$(git rev-parse --show-toplevel)")
	[ "$result" = "$expected" ]
}

@test "get_project_name handles remote URL without .git suffix" {
	git remote add origin https://github.com/aidankinzett/test-repo

	result=$(get_project_name)

	[ "$result" = "test-repo" ]
}

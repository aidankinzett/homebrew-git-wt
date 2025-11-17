#!/usr/bin/env bats

# Tests for symlink_env_files function

load test_helper

setup() {
	setup_test_git_repo
	load_git_wt

	export SOURCE_DIR="$TEST_TEMP_DIR/source"
	export TARGET_DIR="$TEST_TEMP_DIR/target"
	mkdir -p "$SOURCE_DIR" "$TARGET_DIR"
}

teardown() {
	teardown_test_git_repo
}

@test "symlink_env_files creates symlink for .env file" {
	echo "DATABASE_URL=test" >"$SOURCE_DIR/.env"

	run symlink_env_files "$SOURCE_DIR" "$TARGET_DIR"

	[ "$status" -eq 0 ]
	[ -L "$TARGET_DIR/.env" ]
	[ "$(readlink -f "$TARGET_DIR/.env")" = "$(readlink -f "$SOURCE_DIR/.env")" ]
}

@test "symlink_env_files creates symlinks for multiple env files" {
	echo "DEV=true" >"$SOURCE_DIR/.env.development"
	echo "PROD=true" >"$SOURCE_DIR/.env.production"
	echo "BASE=true" >"$SOURCE_DIR/.env"

	run symlink_env_files "$SOURCE_DIR" "$TARGET_DIR"

	[ "$status" -eq 0 ]
	[ -L "$TARGET_DIR/.env" ]
	[ -L "$TARGET_DIR/.env.development" ]
	[ -L "$TARGET_DIR/.env.production" ]
}

@test "symlink_env_files skips files that already exist in target" {
	echo "SOURCE" >"$SOURCE_DIR/.env"
	echo "EXISTING" >"$TARGET_DIR/.env"

	run symlink_env_files "$SOURCE_DIR" "$TARGET_DIR"

	[ "$status" -eq 0 ]
	# Should NOT be a symlink
	[ ! -L "$TARGET_DIR/.env" ]
	# Should still have original content
	[ "$(cat "$TARGET_DIR/.env")" = "EXISTING" ]
}

@test "symlink_env_files handles source directory with no env files" {
	# No .env files in source
	touch "$SOURCE_DIR/some-other-file.txt"

	run symlink_env_files "$SOURCE_DIR" "$TARGET_DIR"

	# Should succeed but not create any symlinks
	[ "$status" -eq 0 ]
	[ ! -e "$TARGET_DIR/.env" ]
}

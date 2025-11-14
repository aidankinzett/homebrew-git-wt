#!/usr/bin/env bats

# Tests for detect_package_manager function

load test_helper

setup() {
    setup_test_git_repo
    load_git_wt
    export TEST_DIR="$TEST_TEMP_DIR/project"
    mkdir -p "$TEST_DIR"
}

teardown() {
    teardown_test_git_repo
}

@test "detect_package_manager finds pnpm from pnpm-lock.yaml" {
    touch "$TEST_DIR/pnpm-lock.yaml"
    touch "$TEST_DIR/package.json"

    result=$(detect_package_manager "$TEST_DIR")

    [ "$result" = "pnpm" ]
}

@test "detect_package_manager finds yarn from yarn.lock" {
    touch "$TEST_DIR/yarn.lock"
    touch "$TEST_DIR/package.json"

    result=$(detect_package_manager "$TEST_DIR")

    [ "$result" = "yarn" ]
}

@test "detect_package_manager finds npm from package-lock.json" {
    touch "$TEST_DIR/package-lock.json"
    touch "$TEST_DIR/package.json"

    result=$(detect_package_manager "$TEST_DIR")

    [ "$result" = "npm" ]
}

@test "detect_package_manager prefers pnpm when multiple lock files exist" {
    touch "$TEST_DIR/pnpm-lock.yaml"
    touch "$TEST_DIR/yarn.lock"
    touch "$TEST_DIR/package-lock.json"
    touch "$TEST_DIR/package.json"

    result=$(detect_package_manager "$TEST_DIR")

    [ "$result" = "pnpm" ]
}

@test "detect_package_manager defaults to pnpm when package.json exists but no lock file" {
    touch "$TEST_DIR/package.json"

    result=$(detect_package_manager "$TEST_DIR")

    [ "$result" = "pnpm" ]
}

@test "detect_package_manager returns empty when no package.json exists" {
    result=$(detect_package_manager "$TEST_DIR")

    [ -z "$result" ]
}

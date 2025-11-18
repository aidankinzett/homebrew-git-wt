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
    echo "DATABASE_URL=test" > "$SOURCE_DIR/.env"

    run symlink_env_files "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    [ -L "$TARGET_DIR/.env" ]
    [ "$(readlink -f "$TARGET_DIR/.env")" = "$(readlink -f "$SOURCE_DIR/.env")" ]
}

@test "symlink_env_files creates symlinks for multiple env files" {
    echo "DEV=true" > "$SOURCE_DIR/.env.development"
    echo "PROD=true" > "$SOURCE_DIR/.env.production"
    echo "BASE=true" > "$SOURCE_DIR/.env"

    run symlink_env_files "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    [ -L "$TARGET_DIR/.env" ]
    [ -L "$TARGET_DIR/.env.development" ]
    [ -L "$TARGET_DIR/.env.production" ]
}

@test "symlink_env_files skips files that already exist in target" {
    echo "SOURCE" > "$SOURCE_DIR/.env"
    echo "EXISTING" > "$TARGET_DIR/.env"

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

# Tests for refresh_env_symlinks function

@test "refresh_env_symlinks removes old symlinks and creates new ones" {
    # Create old env file in source and symlink it
    echo "OLD=true" > "$SOURCE_DIR/.env"
    ln -s "$SOURCE_DIR/.env" "$TARGET_DIR/.env"

    # Now replace with new env file
    rm "$SOURCE_DIR/.env"
    echo "NEW=true" > "$SOURCE_DIR/.env.local"

    run refresh_env_symlinks "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    # Old symlink should be removed
    [ ! -e "$TARGET_DIR/.env" ]
    # New symlink should be created
    [ -L "$TARGET_DIR/.env.local" ]
    [ "$(readlink -f "$TARGET_DIR/.env.local")" = "$(readlink -f "$SOURCE_DIR/.env.local")" ]
}

@test "refresh_env_symlinks handles multiple env files being renamed" {
    # Create old env files and symlink them
    echo "DEV=old" > "$SOURCE_DIR/.env.dev"
    echo "PROD=old" > "$SOURCE_DIR/.env.prod"
    ln -s "$SOURCE_DIR/.env.dev" "$TARGET_DIR/.env.dev"
    ln -s "$SOURCE_DIR/.env.prod" "$TARGET_DIR/.env.prod"

    # Rename env files in source
    rm "$SOURCE_DIR/.env.dev" "$SOURCE_DIR/.env.prod"
    echo "DEV=new" > "$SOURCE_DIR/.env.development"
    echo "PROD=new" > "$SOURCE_DIR/.env.production"

    run refresh_env_symlinks "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    # Old symlinks should be removed
    [ ! -e "$TARGET_DIR/.env.dev" ]
    [ ! -e "$TARGET_DIR/.env.prod" ]
    # New symlinks should be created
    [ -L "$TARGET_DIR/.env.development" ]
    [ -L "$TARGET_DIR/.env.production" ]
}

@test "refresh_env_symlinks fails when target directory doesn't exist" {
    echo "TEST=true" > "$SOURCE_DIR/.env"

    run refresh_env_symlinks "$SOURCE_DIR" "$TARGET_DIR/nonexistent"

    [ "$status" -eq 1 ]
}

@test "refresh_env_symlinks handles no existing symlinks" {
    # No symlinks in target, but env files exist in source
    echo "NEW=true" > "$SOURCE_DIR/.env"

    run refresh_env_symlinks "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    # New symlink should be created
    [ -L "$TARGET_DIR/.env" ]
}

@test "refresh_env_symlinks handles no env files in source" {
    # Create old symlink
    echo "OLD=true" > "$SOURCE_DIR/.env"
    ln -s "$SOURCE_DIR/.env" "$TARGET_DIR/.env"

    # Remove env file from source
    rm "$SOURCE_DIR/.env"

    run refresh_env_symlinks "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    # Old symlink should be removed
    [ ! -e "$TARGET_DIR/.env" ]
}

@test "refresh_env_symlinks removes broken symlinks" {
    # Create a broken symlink
    ln -s "$SOURCE_DIR/.env.missing" "$TARGET_DIR/.env.missing"

    # Create actual env file in source
    echo "NEW=true" > "$SOURCE_DIR/.env"

    run refresh_env_symlinks "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    # Broken symlink should be removed
    [ ! -e "$TARGET_DIR/.env.missing" ]
    # New symlink should be created
    [ -L "$TARGET_DIR/.env" ]
}

@test "refresh_env_symlinks skips regular files (not symlinks)" {
    # Create a regular file (not a symlink) in target
    echo "CUSTOM_CONFIG=true" > "$TARGET_DIR/.env.custom"

    # Create env file in source with same name
    echo "SOURCE_CONFIG=true" > "$SOURCE_DIR/.env.custom"

    # Create another env file that should be symlinked
    echo "AUTO=true" > "$SOURCE_DIR/.env"

    run refresh_env_symlinks "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    # Regular file should be preserved
    [ -f "$TARGET_DIR/.env.custom" ]
    [ ! -L "$TARGET_DIR/.env.custom" ]
    [ "$(cat "$TARGET_DIR/.env.custom")" = "CUSTOM_CONFIG=true" ]
    # New symlink should be created
    [ -L "$TARGET_DIR/.env" ]
}

@test "refresh_env_symlinks handles mix of symlinks and regular files" {
    # Create mix of symlinks and regular files
    echo "SOURCE1=true" > "$SOURCE_DIR/.env"
    ln -s "$SOURCE_DIR/.env" "$TARGET_DIR/.env"
    echo "CUSTOM=true" > "$TARGET_DIR/.env.custom"

    # Update source with new env files
    rm "$SOURCE_DIR/.env"
    echo "NEW1=true" > "$SOURCE_DIR/.env.local"
    echo "NEW2=true" > "$SOURCE_DIR/.env.test"

    run refresh_env_symlinks "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    # Old symlink should be removed
    [ ! -e "$TARGET_DIR/.env" ]
    # Regular file should be preserved
    [ -f "$TARGET_DIR/.env.custom" ]
    [ ! -L "$TARGET_DIR/.env.custom" ]
    # New symlinks should be created
    [ -L "$TARGET_DIR/.env.local" ]
    [ -L "$TARGET_DIR/.env.test" ]
}

@test "refresh_env_symlinks handles adding new env files" {
    # Start with one env file
    echo "BASE=true" > "$SOURCE_DIR/.env"
    ln -s "$SOURCE_DIR/.env" "$TARGET_DIR/.env"

    # Add more env files
    echo "DEV=true" > "$SOURCE_DIR/.env.development"
    echo "PROD=true" > "$SOURCE_DIR/.env.production"

    run refresh_env_symlinks "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    # All symlinks should exist
    [ -L "$TARGET_DIR/.env" ]
    [ -L "$TARGET_DIR/.env.development" ]
    [ -L "$TARGET_DIR/.env.production" ]
}

@test "refresh_env_symlinks removes all old symlinks when all env files are removed" {
    # Create multiple env files and symlink them
    echo "ENV1=true" > "$SOURCE_DIR/.env"
    echo "ENV2=true" > "$SOURCE_DIR/.env.local"
    ln -s "$SOURCE_DIR/.env" "$TARGET_DIR/.env"
    ln -s "$SOURCE_DIR/.env.local" "$TARGET_DIR/.env.local"

    # Remove all env files from source
    rm "$SOURCE_DIR/.env" "$SOURCE_DIR/.env.local"

    run refresh_env_symlinks "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    # All symlinks should be removed
    [ ! -e "$TARGET_DIR/.env" ]
    [ ! -e "$TARGET_DIR/.env.local" ]
}

@test "refresh_env_symlinks real-world scenario: renaming .env to .env.local" {
    # Simulate the user's scenario
    # Initially: .env exists and is symlinked
    echo "DATABASE_URL=postgres://localhost" > "$SOURCE_DIR/.env"
    ln -s "$SOURCE_DIR/.env" "$TARGET_DIR/.env"

    # User renames .env to .env.local in base repo
    mv "$SOURCE_DIR/.env" "$SOURCE_DIR/.env.local"

    run refresh_env_symlinks "$SOURCE_DIR" "$TARGET_DIR"

    [ "$status" -eq 0 ]
    # Old .env symlink should be removed
    [ ! -e "$TARGET_DIR/.env" ]
    # New .env.local symlink should be created
    [ -L "$TARGET_DIR/.env.local" ]
    # Content should be preserved
    [ "$(cat "$TARGET_DIR/.env.local")" = "DATABASE_URL=postgres://localhost" ]
}

# Testing git-wt

This directory contains unit tests for the `git-wt` bash script using [bats-core](https://github.com/bats-core/bats-core).

## Setup

### Install bats-core

**macOS:**

```bash
brew install bats-core
```

**Linux (Debian/Ubuntu):**

```bash
sudo apt-get install bats
```

**Using npm:**

```bash
npm install -g bats
```

### Install bats helper libraries (optional but recommended)

```bash
brew install bats-support bats-assert bats-file
```

Or manually:

```bash
git clone https://github.com/bats-core/bats-support test/test_helper/bats-support
git clone https://github.com/bats-core/bats-assert test/test_helper/bats-assert
git clone https://github.com/bats-core/bats-file test/test_helper/bats-file
```

## Running Tests

### Run all tests

```bash
bats test/
```

### Run specific test file

```bash
bats test/project_name.bats
```

### Run tests with verbose output

```bash
bats --verbose test/
```

### Run tests with tap output (for CI)

```bash
bats --tap test/
```

## Test Structure

```
test/
├── README.md              # This file
├── test_helper.bash       # Shared test setup and helper functions
├── project_name.bats      # Tests for get_project_name()
├── package_manager.bats   # Tests for detect_package_manager()
├── env_symlink.bats       # Tests for symlink_env_files()
└── ...                    # More test files
```

## Writing Tests

Each `.bats` file contains tests for a specific function or feature:

```bash
#!/usr/bin/env bats

load test_helper

setup() {
    # Runs before each test
    setup_test_git_repo
    load_git_wt
}

teardown() {
    # Runs after each test
    teardown_test_git_repo
}

@test "descriptive test name" {
    # Arrange
    # ... setup test data

    # Act
    result=$(function_to_test)

    # Assert
    [ "$result" = "expected_value" ]
}
```

## CI Integration

Add to GitHub Actions workflow:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install bats
        run: |
          sudo apt-get update
          sudo apt-get install -y bats
      - name: Run tests
        run: bats test/
```

## Testing Philosophy

- Test individual functions in isolation
- Use temporary directories for file system operations
- Clean up after each test
- Mock external dependencies where appropriate
- Focus on pure functions first (no side effects)

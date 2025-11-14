.PHONY: test test-verbose test-tap lint help

# Run all tests
test:
	@echo "Running tests..."
	@bats test/

# Run tests with verbose output
test-verbose:
	@echo "Running tests (verbose)..."
	@bats --verbose test/

# Run tests with TAP output (for CI)
test-tap:
	@bats --tap test/

# Lint bash script with shellcheck
lint:
	@echo "Linting git-wt script..."
	@shellcheck git-wt

# Run both lint and test
check: lint test
	@echo "All checks passed!"

# Install bats (macOS only)
install-bats:
	@echo "Installing bats-core..."
	@brew install bats-core

# Show help
help:
	@echo "Available targets:"
	@echo "  make test          - Run all tests"
	@echo "  make test-verbose  - Run tests with verbose output"
	@echo "  make test-tap      - Run tests with TAP output (for CI)"
	@echo "  make lint          - Lint bash script with shellcheck"
	@echo "  make check         - Run lint + test"
	@echo "  make install-bats  - Install bats-core (macOS only)"
	@echo "  make help          - Show this help message"

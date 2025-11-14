# git-wt

[![Tests](https://github.com/aidankinzett/homebrew-git-wt/actions/workflows/test.yml/badge.svg)](https://github.com/aidankinzett/homebrew-git-wt/actions/workflows/test.yml)

Interactive git worktree manager with automatic dependency installation and smart cleanup.

## Installation

### Homebrew (Recommended)

```bash
brew tap aidankinzett/git-wt
brew install --HEAD git-wt
```

### Manual

```bash
curl -fsSL https://raw.githubusercontent.com/aidankinzett/homebrew-git-wt/main/git-wt \
  -o ~/.local/bin/git-wt && chmod +x ~/.local/bin/git-wt
```

## Quick Start

```bash
# Launch interactive fuzzy finder
git-wt

# Or directly create/open a worktree
git-wt feature/my-branch

# List all worktrees
git-wt --list

# Remove a worktree
git-wt --remove feature/my-branch

# Clean up stale references
git-wt --prune
```

## Features

### Interactive Fuzzy Finder

Run `git-wt` with no arguments to browse branches interactively:

- Browse all local and remote branches
- Visual indicators:
  - `✓` - Branch has an existing worktree
  - `[current]` - Currently checked out branch
  - `[remote only]` - Branch exists only on remote
- Preview pane showing worktree path, status, size, and recent commits
- Press `Enter` to create or open a worktree
- Press `Esc` to cancel

### Automatic Setup

When creating a worktree, git-wt automatically:

1. Fetches latest from remote
2. Detects branch location (local, remote, or creates new)
3. Symlinks `.env` files from main worktree
4. Detects package manager (pnpm, yarn, or npm)
5. Installs dependencies
6. Opens in Cursor (if installed)

### Organized Storage

All worktrees are stored in:
```
~/Git/.worktrees/<project-name>/<branch-name>
```

## Usage

### Interactive Mode

```bash
git-wt
```

### Direct Mode

```bash
git-wt <branch-name>
```

### List Worktrees

```bash
git-wt --list  # or -l
```

### Remove Worktree

```bash
git-wt --remove <branch-name>  # or -r
```

### Prune Stale References

```bash
git-wt --prune  # or -p
```

## Development

### Running Tests

```bash
# Install bats (macOS)
brew install bats-core

# Run all tests
make test

# Run tests with verbose output
make test-verbose

# Run lint + test
make check
```

See [test/README.md](test/README.md) for more details on testing.

### Linting

```bash
# Install shellcheck (macOS)
brew install shellcheck

# Run linter
make lint
```

## License

MIT

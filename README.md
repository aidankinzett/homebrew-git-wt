# git-wt

[![Tests](https://github.com/aidankinzett/homebrew-git-wt/actions/workflows/test.yml/badge.svg)](https://github.com/aidankinzett/homebrew-git-wt/actions/workflows/test.yml)
[![codecov](https://codecov.io/gh/aidankinzett/homebrew-git-wt/branch/main/graph/badge.svg)](https://codecov.io/gh/aidankinzett/homebrew-git-wt)

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

## Updating

### Homebrew

Since git-wt is installed from HEAD (latest main branch), you can update to the latest version using:

```bash
# Update to latest version (only if changes exist)
brew upgrade --fetch-HEAD git-wt

# Or force reinstall from latest HEAD
brew reinstall git-wt
```

### Manual

Re-run the installation command to get the latest version:

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

# Refresh env file symlinks
git-wt --refresh-env
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
- Keybindings:
  - `Enter` - Create or open a worktree
  - `d` - Delete the selected worktree. If the command fails, an interactive prompt will ask to force the deletion.
  - `r` - Recreate the worktree from scratch. This will also prompt to force if the initial deletion fails.
  - `Esc` - Cancel the operation. In confirmation prompts, this is equivalent to selecting "No".

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

### Auto-Pruning

Automatically clean up worktrees for merged branches:

```bash
# Enable auto-pruning for current repository
git-wt --enable-autoprune

# Manually cleanup merged branches
git-wt --cleanup

# Disable auto-pruning
git-wt --disable-autoprune
```

When enabled, git-wt automatically removes worktrees for branches that have been merged into main/master (only if there are no uncommitted changes).

### Environment File Sync

Keep `.env` files synchronized across all worktrees when they change in the main repository:

```bash
# Refresh env symlinks in all worktrees
git-wt --refresh-env

# Refresh env symlinks in a specific worktree
git-wt --refresh-env feature/my-branch
```

This is useful when:
- You rename env files (e.g., from `.env` to `.env.local`)
- You add new env files to the main repository
- Env file symlinks become stale or broken

The command removes old env symlinks and creates new ones based on the current `.env*` files in your main worktree.

## Configuration

### Custom Worktree Path

You can customize where worktrees are stored using git config or environment variables:

```bash
# Set globally for all repositories
git config --global worktree.basepath ~/custom/path

# Set for current repository only
git config --local worktree.basepath ~/custom/path

# Or use environment variable
export GIT_WT_BASE=~/custom/path
```

**Priority order:** local git config > global git config > environment variable > default (`~/Git/.worktrees`)

### Migrating Existing Worktrees

If you change your worktree base path configuration, existing worktrees in the old location won't be automatically detected by git-wt. Here's how to migrate them:

**Option 1: Move worktrees to the new location**

```bash
# Example: Moving from old location to new location
OLD_PATH=~/Git/.worktrees
NEW_PATH=~/custom/path

# Move the entire project directory
mv $OLD_PATH/my-project $NEW_PATH/my-project

# Update git's worktree references
git worktree repair
```

**Option 2: Keep worktrees in place and adjust your configuration**

If you have existing worktrees you want to keep using:

```bash
# Check where your existing worktrees are
git worktree list

# Set your config to match that location
git config --global worktree.basepath /path/to/existing/worktrees
```

**Note:** git-wt will warn you if it detects existing worktrees in different locations when you run `git-wt --list` or `git-wt`.

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

### Refresh Environment Files

```bash
# Refresh env symlinks in all worktrees
git-wt --refresh-env

# Refresh env symlinks in a specific worktree
git-wt --refresh-env <branch-name>
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

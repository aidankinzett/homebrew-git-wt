# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Note:** This project currently uses a HEAD-only Homebrew formula (no versioned releases).
The changelog tracks changes for future reference, but versions are not tagged in git.

## [Unreleased]

### Added
- **Interactive fuzzy finder mode** (Phase 1 complete!)
  - Launch with `git-wt` (no arguments) to browse all branches
  - Visual indicators for existing worktrees (✓), current branch, remote-only branches
  - Preview pane showing worktree details:
    - Path and git status
    - Directory size (total + node_modules)
    - Last modified time
    - Recent commits (last 3)
  - Press Enter to create or open worktree
  - Press Esc to cancel
  - fzf integration with ANSI color support
- Direct branch access: `git-wt <branch-name>` skips fuzzy finder
- Flag-based commands: `--list`, `--remove`, `--prune`, `--help`
- fzf installation check with helpful error messages
- Automatic worktree creation with smart branch detection
- Environment file symlinking from main repo to worktrees
- Package manager detection (pnpm/yarn/npm) with automatic dependency installation
- Cursor editor integration (auto-opens worktree)
- `list` command for showing all worktrees
- `remove` command for deleting worktrees
- `prune` command for cleaning up stale references
- Organized worktree storage at `~/Git/.worktrees/<project>/<branch>`
- Homebrew tap distribution (HEAD-only)
- Colored terminal output for better UX

### Changed
- **BREAKING:** Removed `add` subcommand - use direct syntax instead: `git-wt <branch>` (not `git-wt add <branch>`)
- Default behavior changed: running `git-wt` with no args now launches fuzzy finder (was: show help)
- Commands now use flag syntax: `--list` instead of `list`, `--remove` instead of `remove`, etc.
- Help documentation updated to reflect new interactive mode and command structure

### Removed
- `add` subcommand (replaced by direct branch syntax)

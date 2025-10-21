# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

**Note:** This project currently uses a HEAD-only Homebrew formula (no versioned releases).
The changelog tracks changes for future reference, but versions are not tagged in git.

## [Unreleased]

### Added
- Automatic worktree creation with smart branch detection
- Environment file symlinking from main repo to worktrees
- Package manager detection (pnpm/yarn/npm) with automatic dependency installation
- Cursor editor integration (auto-opens worktree)
- `add` command for creating worktrees
- `list` command for showing all worktrees
- `remove` command for deleting worktrees
- `prune` command for cleaning up stale references
- Organized worktree storage at `~/Git/.worktrees/<project>/<branch>`
- Homebrew tap distribution (HEAD-only)
- Colored terminal output for better UX

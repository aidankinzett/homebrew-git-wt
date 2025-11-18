# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Pushing to Remote

You are allowed to commit, but don't push up to GitHub unless instructed by the user.

## Project Overview

`git-wt` is a Bash-based interactive git worktree manager that simplifies creating, managing, and cleaning up git worktrees. It's distributed as a Homebrew tap.

## Architecture

### Core Components

- **`git-wt`** (main executable): Bash script that handles all worktree operations
- **`Formula/git-wt.rb`**: Homebrew formula for installation
- **`docs/plans/`**: Design documents for planned features

### Worktree Storage Structure

All worktrees are stored at: `<base-path>/<project-name>/<branch-name>`

Where:
- `<base-path>` is configurable (default: `~/Git/.worktrees`)
- `<project-name>` is extracted from the git remote URL (falls back to directory name if no remote)

**Base path priority:**
1. Local git config: `git config --local worktree.basepath`
2. Global git config: `git config --global worktree.basepath`
3. Environment variable: `$GIT_WT_BASE`
4. Default: `~/Git/.worktrees`

### Key Functions

- `get_worktree_base()` (lib/config.sh:7): Gets configurable base path with priority: local config > global config > env var > default
- `get_project_name()` (lib/git-utils.sh:17): Extracts project name from remote URL or directory
- `detect_package_manager()` (lib/package-manager.sh:13): Detects pnpm/yarn/npm based on lock files
- `symlink_env_files()` (lib/package-manager.sh:33): Symlinks `.env*` files from main repo to worktree
- `cmd_add()` (lib/commands.sh:6): Creates worktree with automatic setup (fetch, install deps, symlink env, open in Cursor)
- `cmd_list()` (lib/commands.sh:130): Lists all worktrees for current project
- `cmd_remove()` (lib/commands.sh:172): Removes worktree and cleans up empty directories
- `cmd_prune()` (lib/commands.sh:211): Removes stale worktree references
- `auto_prune_stale_worktrees()` (lib/worktree-ops.sh:61): Automatically prunes merged branches with no uncommitted changes

## Development Commands

### Testing Changes Locally

```bash
# Test the script directly (without installing)
./git-wt add test-branch
./git-wt list
./git-wt remove test-branch
./git-wt --help
```

### Installing via Homebrew for Testing

```bash
# Install from local tap (HEAD = latest main branch)
brew install --HEAD git-wt

# After making changes to main and pushing, reinstall to get latest HEAD
# Note: --HEAD flag is only needed for initial install, not for reinstall
brew reinstall git-wt

# Alternative: Use upgrade to only update if there are changes
brew upgrade --fetch-HEAD git-wt
```

### Linting

Use `shellcheck` for bash linting:
```bash
shellcheck git-wt
```

## Important Implementation Details

### Branch Detection Priority (git-wt:149-174)

The script checks for branches in this order:
1. **Local branch exists** → Use it (most common case)
2. **Remote branch exists** → Create local tracking branch
3. **Neither exists** → Create new branch from current HEAD

This prioritization matches git's default behavior and prevents accidentally creating duplicate branches.

### Package Manager Detection (git-wt:91-108)

Detection based on lock files in this order:
1. `pnpm-lock.yaml` → pnpm
2. `yarn.lock` → yarn
3. `package-lock.json` → npm
4. Falls back to pnpm if `package.json` exists but no lock file

### Environment File Symlinking (git-wt:111-136)

- Finds all `.env` and `.env.*` files in main worktree
- Creates symlinks in new worktree (skips if file already exists)
- Prevents duplication of sensitive environment variables

### Cursor Integration (git-wt:647-653)

After creating worktree, automatically opens in Cursor if the `cursor` command is available. Falls back to printing the `cd` command if not.

## Planned Enhancements

See `docs/plans/2025-10-21-git-wt-enhancements-design.md` for comprehensive design of upcoming features:

1. **Interactive fuzzy finder** (using fzf)
   - Visual indicators for existing worktrees
   - Preview pane showing worktree status, size, recent commits
   - Keybindings: Enter (open/create), d (delete), r (recreate)

2. **Auto-pruning system**
   - Automatically clean up stale worktrees based on:
     - Remote branch deleted/merged
     - Time-based staleness (14+ days since commit)
     - Access-based staleness (7+ days since last access)
   - Safety guardrails prevent deletion of uncommitted work

3. **Simplified command structure**
   - `git-wt` (no args) → launches fuzzy finder
   - `git-wt <branch>` → directly create/open branch
   - Flag-based commands: `--list`, `--remove`, `--cleanup`

## Homebrew Distribution

### Formula Structure (Formula/git-wt.rb)

- Uses `head` formula (installs from latest main branch)
- Depends on `fzf` (for future fuzzy finder feature)
- Simple installation: copies `git-wt` to Homebrew's bin directory

### Tap Naming Convention

- **Repository**: `aidankinzett/homebrew-git-wt` (must have "homebrew-" prefix)
- **Tap name**: `aidankinzett/git-wt` (Homebrew automatically strips "homebrew-" prefix)
- **Formula name**: `git-wt` (from `Formula/git-wt.rb`)

Homebrew automatically resolves `brew tap user/name` to `github.com/user/homebrew-name`.

### Installing the Tap

```bash
brew tap aidankinzett/git-wt      # Taps github.com/aidankinzett/homebrew-git-wt
brew install --HEAD git-wt         # Installs Formula/git-wt.rb
```

### Deployment Process

**There is no deployment process!** Since this is HEAD-only:

1. Make changes to `git-wt` or `Formula/git-wt.rb`
2. Commit and push to main branch
3. That's it - users can now install/update

Users update with:
```bash
# Reinstall to get latest from HEAD (always reinstalls even if no changes)
brew reinstall git-wt

# OR check for updates first, only upgrade if changes exist
brew upgrade --fetch-HEAD git-wt
```

**No need for:**
- Building/compiling (it's a bash script)
- CI/CD pipelines
- Release artifacts
- Git tags or releases

### Versioning Strategy

**Current approach: HEAD-only (no stable releases)**

The formula only defines `head`, which means:
- Users always get the latest commit from main branch
- No version pinning or git tags needed
- Install command requires `--HEAD` flag
- Updates are simple: just push to main

**Why HEAD-only:**
- Project is in active development (fuzzy finder and auto-pruning planned)
- Faster iteration without release overhead
- Simpler maintenance for early stage

**Future: When to add stable releases**

Add a `url` and `sha256` to the formula when:
- Major features are complete and stable (post fuzzy finder + auto-pruning)
- You want to protect users from breaking changes
- You need version pinning for compatibility

**Stable release workflow** (for future reference):
1. Create git tag: `git tag v0.2.0 && git push origin v0.2.0`
2. Download tarball: `curl -sL https://github.com/aidankinzett/homebrew-git-wt/archive/refs/tags/v0.2.0.tar.gz -o release.tar.gz`
3. Get SHA256: `shasum -a 256 release.tar.gz`
4. Update formula:
   ```ruby
   url "https://github.com/aidankinzett/homebrew-git-wt/archive/refs/tags/v0.2.0.tar.gz"
   sha256 "abc123..."
   ```
5. Users can then install without `--HEAD`: `brew install git-wt`

## Testing Considerations

When testing changes:
- Test with repositories that have remote branches
- Test with repositories without remotes
- Test with different package managers (pnpm, yarn, npm, none)
- Test with and without `.env` files
- Test branch name edge cases (slashes, special characters)
- Test with and without Cursor installed

## Pull Request Guidelines

### Documentation Updates

**IMPORTANT**: Always update the README.md when making changes that affect:
- User-facing behavior (new commands, changed command syntax)
- Installation instructions
- Feature availability (moving features from "Planned" to "Current")
- Usage examples
- Configuration options

The README is the primary documentation for users. Keep it in sync with the code.

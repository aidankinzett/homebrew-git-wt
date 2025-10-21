# git-wt

> Interactive git worktree manager with smart cleanup

`git-wt` is a command-line tool that makes git worktrees simple and automatic. Create isolated development environments for each branch, with automatic dependency installation, `.env` file symlinking, and smart cleanup.

## Why git-wt?

**Problem:** Switching branches means losing context - uncommitted changes, running dev servers, and local state all get disrupted.

**Solution:** git worktrees let you have multiple branches checked out simultaneously in different directories. But managing them manually is tedious.

**git-wt makes it easy:**
```bash
git-wt add feature/new-api
# → Creates worktree
# → Symlinks .env files
# → Installs dependencies (pnpm/yarn/npm)
# → Opens in Cursor
# Ready to code in 30 seconds
```

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

### Dependencies

- [fzf](https://github.com/junegunn/fzf) - Required for interactive mode (planned feature)
  ```bash
  brew install fzf
  ```

## Quick Start

```bash
# In any git repository
cd ~/my-project

# Create a worktree for a branch
git-wt add feature/dashboard

# List all worktrees
git-wt list

# Remove a worktree when done
git-wt remove feature/dashboard

# Clean up stale references
git-wt prune
```

## Current Features

### Automatic Worktree Setup

When creating a worktree, git-wt automatically:

1. **Fetches latest from remote** - Ensures you're working with up-to-date code
2. **Detects branch location** - Works with remote branches, local branches, or creates new ones
3. **Symlinks .env files** - Your environment variables are available in every worktree
4. **Detects package manager** - Checks for pnpm-lock.yaml, yarn.lock, or package-lock.json
5. **Installs dependencies** - Runs the appropriate install command automatically
6. **Opens in Cursor** - Starts your editor immediately (if Cursor is installed)

### Smart Branch Handling

```bash
# Remote branch exists → Creates local tracking branch
git-wt add feature/from-teammate

# Local branch exists → Uses it
git-wt add my-local-branch

# Branch doesn't exist → Creates new branch
git-wt add feature/new-idea
```

### Organized Storage

All worktrees are stored in a consistent location:
```
~/Git/.worktrees/<project-name>/<branch-name>
```

This makes them:
- Easy to find
- Easy to backup/exclude from backups
- Separate from your main workspace

## Usage

### Create Worktree

```bash
git-wt add <branch-name>
```

**Examples:**
```bash
# Pull down a PR branch
git-wt add feature/team-member-pr

# Start new feature
git-wt add feature/my-new-feature

# Work on existing branch
git-wt add bugfix/login-issue
```

### List Worktrees

```bash
git-wt list
```

Shows all worktrees for the current project with their paths and branches.

### Remove Worktree

```bash
git-wt remove <branch-name>
```

Removes the worktree and cleans up the directory structure.

### Prune Stale References

```bash
git-wt prune
```

Removes worktree references for directories that no longer exist.

## Planned Enhancements

We're working on major improvements! See [Design Document](docs/plans/2025-10-21-git-wt-enhancements-design.md) for full details.

### Interactive Fuzzy Finder

```bash
git-wt  # No arguments → launches interactive mode
```

- Browse all branches (local + remote) with fzf
- See which branches already have worktrees (✓ indicator)
- Preview pane showing worktree info, size, and recent commits
- Keybindings:
  - `Enter` - Open existing or create new worktree
  - `d` - Delete worktree
  - `r` - Recreate worktree (fresh install)

### Auto-Pruning

Automatically clean up stale worktrees to save disk space:

**Stale criteria:**
- Branch merged/deleted on remote
- No commits in 14+ days
- Not accessed in 7+ days

**Safety:**
- Never removes uncommitted changes
- Never removes recently modified files
- Shows what was removed and space freed

**Configuration:**
```bash
# In ~/.gitconfig or .git/config
[worktree]
    autoprune = true
    staleAfterDays = 14
    accessedWithinDays = 7
```

### Simplified Commands

```bash
git-wt                    # Interactive fuzzy finder
git-wt feature/branch     # Direct to branch
git-wt --list            # List worktrees
git-wt --cleanup         # Force cleanup stale worktrees
```

## Development

### Setup

```bash
# Clone the repo
git clone https://github.com/aidankinzett/homebrew-git-wt.git
cd homebrew-git-wt

# Test changes directly
./git-wt --help

# Or install via Homebrew for testing
brew install --HEAD aidankinzett/git-wt
```

### Development Workflow

```bash
# Make changes
vim git-wt

# Test locally
./git-wt add test-branch

# When ready, push and reinstall
git push
brew reinstall --HEAD aidankinzett/git-wt
```

### Project Structure

```
homebrew-git-wt/
├── git-wt                  # Main script
├── Formula/
│   └── git-wt.rb          # Homebrew formula
├── docs/
│   └── plans/             # Design documents
└── README.md
```

## Contributing

Contributions welcome! Whether it's:

- Bug reports
- Feature requests
- Code improvements
- Documentation updates

### Guidelines

1. **Test your changes** - Run the script on actual git repositories
2. **Follow bash best practices** - Use shellcheck for linting
3. **Update docs** - Keep README and design docs in sync
4. **Small PRs** - Easier to review and merge

### Areas for Contribution

- [ ] Implement fuzzy finder (see [design doc](docs/plans/2025-10-21-git-wt-enhancements-design.md))
- [ ] Add auto-pruning logic
- [ ] Improve error messages
- [ ] Add bash completion
- [ ] Support for other editors (VS Code, Vim, etc.)
- [ ] Windows/WSL support

## FAQ

### How is this different from manually managing worktrees?

git-wt automates the tedious parts:
- No need to remember worktree paths
- Automatic dependency installation
- .env file symlinking
- Editor integration
- Smart cleanup

### Can I use this with existing worktrees?

Yes! git-wt works alongside manually created worktrees.

### What happens to my main working directory?

Nothing! git-wt creates separate worktrees, your main directory stays untouched.

### Can I customize where worktrees are stored?

Currently they're stored in `~/Git/.worktrees/`. Customization coming in future release.

### Does this work with monorepos?

Yes! git-wt detects the project name and creates separate worktree directories per project.

## Troubleshooting

### Command not found

Make sure `~/bin` or `~/.local/bin` is in your PATH:
```bash
export PATH="$HOME/bin:$PATH"
```

### Worktree already exists error

Use `git-wt list` to see existing worktrees, or `git-wt remove <branch>` to remove the old one.

### Package manager not detected

git-wt looks for lock files (pnpm-lock.yaml, yarn.lock, package-lock.json). If you don't have a lock file, add one or install dependencies manually.

### Cursor doesn't open

Make sure the `cursor` command is available in your PATH. You can install it from Cursor → Command Palette → "Install 'cursor' command".

## License

MIT

## Acknowledgments

Inspired by the pain of context switching and the power of git worktrees.

---

**Status:** Active development 🚧
**Version:** 0.1.0 (Current features)
**Next:** Interactive fuzzy finder + auto-pruning ([Design](docs/plans/2025-10-21-git-wt-enhancements-design.md))

# git-wt Enhancements Design

**Date:** 2025-10-21
**Status:** Draft
**Author:** Design discussion with team

## Problem Statement

Current git-wt pain points:

1. **Worktree collision discovery**: Users don't know if a branch is already checked out in another worktree until they try to create it
2. **Disk space consumption**: node_modules and build artifacts accumulate in old worktrees that are no longer actively used
3. **Poor visibility**: Hard to see all worktrees and their state at a glance

## Goals

1. Make it obvious which branches have worktrees before attempting to create one
2. Automatically clean up stale worktrees to save disk space
3. Streamline the worktree workflow with an interactive fuzzy finder
4. Maintain safety - never auto-delete work in progress

## Design Overview

Transform git-wt from a command-based tool to an interactive fuzzy finder with smart auto-pruning.

### Core UX Change

**Before:**

```bash
git-wt add feature/dashboard    # Might fail if worktree exists
git-wt list                     # Check what exists
git-wt remove feature/old       # Clean up manually
```

**After:**

```bash
git-wt                          # Interactive fuzzy finder shows all branches
git-wt feature/dashboard        # Direct access (skip fuzzy finder)
git-wt --list                   # List worktrees
git-wt --remove                 # Remove worktree
```

## Command Structure

### Primary Command

```bash
git-wt [branch]
```

**Behavior:**

- **No arguments**: Launch fuzzy finder with all branches
- **Branch provided**: Skip fuzzy finder, directly create/open that branch
- **Flags**: Execute specific command (--list, --remove, --help, etc.)

### Flag Commands

````bash
git-wt --list / -l              # List all worktrees (existing behavior)
git-wt --remove [branch] / -r   # Remove worktree (interactive if no branch)
git-wt --prune / -p             # Prune stale worktree references
git-wt --cleanup                # Force cleanup of all stale worktrees
git-wt --help / -h              # Show help
git-wt --no-autoprune           # Skip auto-prune for this command
```bash

## Fuzzy Finder Design

### Display Format

```text
  feature/dashboard-redesign      ✓  ~/Git/.worktrees/control-centre/...
  feature/new-api                    [remote only]
  fix/login-bug                   ✓  ~/Git/.worktrees/control-centre/...
> main                                [current]
  solana_stake_flow               ✓  [STALE] ~/Git/.worktrees/...
────────────────────────────────────────────────────────────────────
Preview:
  Branch: feature/dashboard-redesign
  Worktree: ~/Git/.worktrees/control-centre/feature/dashboard-redesign
  Status: Clean (✓)
  Last modified: 2 hours ago
  Size: 847 MB (node_modules: 621 MB)

  Recent commits:
  - c906a9e Update dashboard layout (2 hours ago)
  - 849709 Add new fonts (5 hours ago)
────────────────────────────────────────────────────────────────────
[Enter] Open  [d] Delete  [r] Recreate  [Esc] Cancel
````

### Indicators

- `✓` - Branch has active worktree
- `[STALE]` - Worktree exists but meets stale criteria
- `[remote only]` - Branch only exists on remote
- `[current]` - Currently checked out branch

### Keybindings

| Key     | Action      | Behavior                                                            |
| ------- | ----------- | ------------------------------------------------------------------- |
| `Enter` | Open/Create | If worktree exists, open in Cursor. If not, create then open.       |
| `d`     | Delete      | Remove worktree, reload fuzzy finder (stays open for next deletion) |
| `r`     | Recreate    | Delete + create fresh worktree, open in Cursor                      |
| `Esc`   | Cancel      | Exit fuzzy finder                                                   |

### Implementation with fzf

```bash
fzf \
  --ansi \
  --preview 'show_worktree_info {}' \
  --preview-window right:50% \
  --bind 'enter:execute(open_or_create_worktree {})' \
  --bind 'd:reload(delete_worktree {} && regenerate_branch_list)' \
  --bind 'r:reload(recreate_worktree {} && regenerate_branch_list)'
```

**Key fzf features used:**

- `--ansi`: Color support for indicators
- `--preview`: Right panel showing worktree details
- `--bind`: Custom keybindings for d/r/enter
- `reload()`: Keep fuzzy finder open after actions

### Branch List Generation

1. Get all local branches: `git branch --format='%(refname:short)'`
2. Get all remote branches: `git branch -r --format='%(refname:short)'`
3. Get all worktrees: `git worktree list --porcelain`
4. Merge and deduplicate branches
5. For each branch, check if worktree exists
6. Add color-coded indicators
7. Sort: Current branch, worktrees, locals, remotes

### Preview Panel Content

For each selected branch, show:

- Branch name and type (local/remote/both)
- Worktree path (if exists)
- Git status (clean/dirty, ahead/behind remote)
- Last modified time (most recent file change)
- Directory size (total and node_modules breakdown)
- Last 3 commits with timestamps
- Stale indicator (if applicable)

## Auto-Pruning System

### Stale Worktree Criteria

A worktree is considered **stale** when ANY of these conditions are true:

1. **Remote branch deleted/merged**
   - Branch no longer exists on `origin`
   - OR branch has been merged into `main`/`master`

2. **Time-based staleness**
   - Last Git commit > 14 days ago (configurable)
   - AND no files modified in last 24 hours

3. **Access-based staleness**
   - Directory not accessed in > 7 days (via `stat` mtime)

### Safety Guardrails

Auto-pruning is **blocked** if ANY of these are true:

1. **Uncommitted changes**
   - `git status --porcelain` shows any output
   - Prevents data loss

2. **Recent activity**
   - Any file modified in last 24 hours
   - Indicates active work even if branch is old

### Auto-Prune Behavior

Every `git-wt` command automatically:

1. Check all managed worktrees for staleness
2. Apply safety guardrails
3. Remove safe-to-delete worktrees
4. Display summary:
   ```text
   [Auto-pruned 2 stale worktrees: feature/old-branch, fix/merged-pr] (1.8GB freed)
   ```

### Configuration

Users can configure auto-pruning behavior:

```bash
# In ~/.gitconfig (global) or .git/config (per-repo)
[worktree]
    autoprune = true                # Enable/disable auto-pruning
    staleAfterDays = 14            # Days since last commit
    accessedWithinDays = 7         # Days since last access
    recentActivityHours = 24       # Hours for "recent activity" check
```

### Manual Control

```bash
# Force cleanup all stale worktrees
git-wt --cleanup

# Skip auto-prune for one command
git-wt --no-autoprune

# See what would be pruned (dry run)
git-wt --cleanup --dry-run
```

## Data Flow

### Opening Fuzzy Finder

```text
git-wt
  ↓
  1. Check for stale worktrees → Auto-prune if enabled
  ↓
  2. Fetch from origin (silent)
  ↓
  3. Generate branch list:
     - Local branches
     - Remote branches
     - Deduplicate
  ↓
  4. For each branch:
     - Check if worktree exists
     - Check if stale
     - Add indicators
  ↓
  5. Launch fzf with formatted list
  ↓
  6. User selects branch + action
  ↓
  7. Execute action (create/open/delete/recreate)
```

### Create/Open Worktree Flow

```text
User presses Enter on branch
  ↓
  Does worktree exist?
  ├─ Yes → Open in Cursor
  │         cursor /path/to/worktree
  │
  └─ No  → Create worktree
            ├─ Fetch from origin
            ├─ Check if branch exists (local/remote/new)
            ├─ Create worktree at ~/Git/.worktrees/<project>/<branch>
            ├─ Symlink .env files
            ├─ Detect package manager
            ├─ Run install (pnpm/yarn/npm)
            └─ Open in Cursor
```

### Delete Worktree Flow

```text
User presses 'd' on branch
  ↓
  Check if worktree exists
  ├─ No  → Show error, reload fuzzy finder
  │
  └─ Yes → Check safety
            ├─ Has uncommitted changes? → Warn, ask confirmation
            └─ Clean → Delete worktree
                      ↓
                      Git worktree remove --force
                      ↓
                      Regenerate branch list
                      ↓
                      Reload fuzzy finder (stays open)
```

## Edge Cases & Error Handling

### Worktree Already Exists

**Scenario:** User tries to create worktree for branch that's already checked out elsewhere

**Handling:**

- Fuzzy finder shows `✓` indicator
- Enter key opens existing worktree (doesn't create duplicate)
- User can use `r` to recreate if needed

### Branch Name Conflicts

**Scenario:** Local and remote have same branch name but different commits

**Handling:**

- Prioritize local branch (as Git does)
- Show tracking status in preview pane
- User can see if local is ahead/behind remote

### Dirty Worktree on Auto-Prune

**Scenario:** Stale worktree has uncommitted changes

**Handling:**

- Safety guardrail blocks auto-prune
- Worktree kept with `[STALE]` indicator
- User can manually review and delete via fuzzy finder

### fzf Not Installed

**Scenario:** User runs `git-wt` but doesn't have fzf

**Handling:**

```bash
Error: fzf is required for interactive mode
Install: brew install fzf (macOS) or apt install fzf (Linux)

Alternatively, use direct mode:
  git-wt <branch-name>
  git-wt --list
```

### No Remote Configured

**Scenario:** repository has no `origin` remote

**Handling:**

- Skip `git fetch origin` (show warning)
- Only show local branches
- Auto-prune based on time/access only

### Cursor Not Installed

**Scenario:** `cursor` command not found

**Handling:**

- Fall back to printing path:
  ```
  Worktree ready at: /path/to/worktree
  To open, run: cd /path/to/worktree
  ```

## Migration from Current Version

### Backward Compatibility

All existing commands still work:

```bash
# These continue to work
git-wt add feature/branch
git-wt list
git-wt remove feature/branch
git-wt prune
```

The `add` command becomes an alias for the direct branch mode:

```bash
git-wt add feature/branch  →  git-wt feature/branch
```

### Breaking Changes

None. All new features are additive.

### Recommended Migration Path

1. Update `git-wt` script in place
2. First run will show new fuzzy finder if no args provided
3. Existing worktrees are compatible (no data migration needed)
4. Auto-pruning disabled by default (opt-in via config)

## Implementation Checklist

### Phase 1: Fuzzy Finder Core

- [ ] Implement branch list generation
- [ ] Add worktree detection and indicators
- [ ] Create fzf integration with keybindings
- [ ] Implement preview pane with worktree info
- [ ] Handle Enter key (create or open)
- [ ] Test with various branch name formats

### Phase 2: Delete/Recreate Actions

- [ ] Implement `d` keybinding (delete worktree)
- [ ] Add safety check for uncommitted changes
- [ ] Implement reload mechanism (keep fuzzy finder open)
- [ ] Implement `r` keybinding (recreate)
- [ ] Add confirmation prompts where needed

### Phase 3: Auto-Pruning

- [ ] Implement stale detection logic
- [ ] Add safety guardrails (uncommitted, recent activity)
- [ ] Create auto-prune function
- [ ] Add configuration support (gitconfig)
- [ ] Implement --cleanup and --no-autoprune flags
- [ ] Add disk space calculation and reporting

### Phase 4: Polish & Error Handling

- [ ] Add fzf installation check
- [ ] Handle all edge cases (no remote, no cursor, etc.)
- [ ] Add color-coded output
- [ ] Improve error messages
- [ ] Add --dry-run for cleanup
- [ ] Update help text

### Phase 5: Documentation

- [ ] Update readme with new features
- [ ] Add examples for fuzzy finder usage
- [ ] Document configuration options
- [ ] Create troubleshooting guide
- [ ] Share with team for feedback

## Success Metrics

1. **Reduced worktree collisions**: No more "worktree already exists" errors
2. **Disk space savings**: Automatic cleanup of stale worktrees
3. **Faster workflow**: Interactive fuzzy finder faster than remembering commands
4. **Team adoption**: Team members actively use git-wt instead of manual worktree commands

## Open Questions

1. Should we add a `--config` command to interactively configure auto-prune settings?
2. Should stale worktrees be visually distinct in fuzzy finder (different color)?
3. Should we track worktree "last accessed" time in a separate metadata file?
4. Should we add a `git-wt status` command showing disk usage breakdown?

## Future Enhancements (Out of Scope)

- Integration with GitHub CLI for PR status in preview pane
- Worktree templates (different .env configs per worktree)
- Team-shared worktree metadata (who's working on what)
- Automatic worktree switching based on active Cursor window
- Worktree snapshots/backup before deletion

# Git Commands Call Reference

## Master List of All Git Commands

### By Frequency (Highest to Lowest)

| Rank | Git Command | Location | Called From | Call Count Example |
|------|-------------|----------|-------------|-------------------|
| 1 | `git worktree list --porcelain` | worktree-ops.sh:28 | has_worktree(), get_worktree_path(), auto_prune_stale_worktrees() | N × (num_branches) + 1 |
| 2 | `git branch --format='%(refname:short)'` | fuzzy-finder.sh:35, 498 | generate_branch_list(), cmd_interactive() | 3-4 times per session |
| 3 | `git branch -r --format='%(refname:short)'` | fuzzy-finder.sh:46, 508 | generate_branch_list(), cmd_interactive() | 2-3 times per session |
| 4 | `git branch --show-current` | fuzzy-finder.sh:27, 492, 202 | generate_branch_list(), cmd_interactive(), show_worktree_info() | 3-5 times |
| 5 | `git branch --merged "$main_branch"` | worktree-ops.sh:72 | is_worktree_stale() | Once per auto-prune |
| 6 | `git -C "$worktree_path" branch --show-current` | worktree-ops.sh:107 | auto_prune_stale_worktrees() | Once per worktree |
| 7 | `git -C "$worktree_path" status --porcelain` | fuzzy-finder.sh:146, 269, 327, 389; worktree-ops.sh:75 | Multiple delete/preview/auto-prune | 3-5 times per session |
| 8 | `git show-ref --verify --quiet "refs/heads/$branch"` | fuzzy-finder.sh:189 | show_worktree_info() | Once per preview |
| 9 | `git ls-remote --heads origin "$branch"` | fuzzy-finder.sh:194 | show_worktree_info() | Once per preview |
| 10 | `git log --oneline --color=always -n 3` | fuzzy-finder.sh:193, 198 | show_worktree_info() | 2x per preview |
| 11 | `git config --get remote.origin.url` | git-utils.sh:20 | get_project_name() | 1-2 times |
| 12 | `git config --get init.defaultBranch` | worktree-ops.sh:63 | is_worktree_stale() | Once per auto-prune |
| 13 | `git rev-parse --git-dir` | git-utils.sh:8 | check_git_repo() | 1 per command |
| 14 | `git rev-parse --show-toplevel` | git-utils.sh:29 | get_project_name() | 1-2 times |
| 15 | `git rev-parse --short HEAD` | fuzzy-finder.sh:208 | show_worktree_info() (for detached HEAD) | 0-1 times |
| 16 | `git worktree add` | commands.sh:51, 59, 67 | cmd_add() | Once per new worktree |
| 17 | `git worktree remove --force` | commands.sh:194; fuzzy-finder.sh:290, 349, 411; worktree-ops.sh:116 | cmd_remove(), delete operations, auto-prune | Once per deletion |
| 18 | `git worktree prune --verbose` | commands.sh:216 | cmd_prune() | Once per prune command |
| 19 | `git fetch origin` | commands.sh:34 | cmd_add() | Once per new worktree |
| 20 | `git ls-remote --heads origin "$branch_name"` | commands.sh:42 | cmd_add() | Once per new worktree |
| 21 | `git show-ref --verify --quiet "refs/heads/$branch_name"` | commands.sh:44 | cmd_add() | Once per new worktree |

---

## Heavy File System Operations (Non-Git)

| Operation | Location | Trigger | Performance Impact |
|-----------|----------|---------|-------------------|
| `find` with `stat` (last modified) | fuzzy-finder.sh:158-162 | Preview pane accessed | Very High - scans entire worktree |
| `du -sh` (worktree size) | fuzzy-finder.sh:171 | Preview pane accessed | High - traverses filesystem |
| `du -sh node_modules` | fuzzy-finder.sh:176 | Preview pane accessed | High - if node_modules large |

---

## Critical Performance Hotspots

### Hotspot 1: Branch List Generation Loop (fuzzy-finder.sh, Lines 52-90)

**Issue**: 4 separate loops over branches, each calling `has_worktree()`

**Code**:
```bash
# First loop (current branch)
for branch_info in "${branches[@]}"; do
    local branch="${branch_info%|*}"
    if [[ "$branch" == "$current_branch" ]]; then
        formatted_branches+=("$(format_branch_line "$branch" "$type" "$current_branch")")
        # calls has_worktree() inside format_branch_line
    fi
done

# Second loop (branches with worktrees)  ← REDUNDANT HAS_WORKTREE CALLS
for branch_info in "${branches[@]}"; do
    if has_worktree "$branch"; then  # ← GIT CALL
        formatted_branches+=("$(format_branch_line ...)")
        # calls has_worktree() AGAIN inside format_branch_line
    fi
done

# Third loop (local branches without worktrees)
# Fourth loop (remote-only branches)
```

**Impact**: 
- 4 `git worktree list --porcelain` calls per branch = 4N total
- For 20 branches = 80 git commands

**Solution**: Single pass, cache `has_worktree` results

### Hotspot 2: Preview Pane File Operations (fuzzy-finder.sh, Lines 154-177)

**Code**:
```bash
# Find most recently modified file (expensive!)
last_modified=$(find "$worktree_path" -type f \
    -not -path "*/node_modules/*" \
    -not -path "*/.git/*" \
    -exec stat -f "%m %N" {} \; | sort -rn | head -1 | awk '{print $1}')

# Calculate sizes (multiple du calls)
total_size=$(du -sh "$worktree_path" 2>/dev/null | awk '{print $1}')

if [[ -d "$worktree_path/node_modules" ]]; then
    nm_size=$(du -sh "$worktree_path/node_modules" 2>/dev/null | awk '{print $1}')
fi
```

**Impact**: 
- `find` with `stat` scans every file in worktree (except .git/node_modules)
- For 500MB worktree with 1000+ files = slow preview
- Called every time user selects a worktree in fuzzy finder

**Solution**: Cache results, disable by default or lazy-load

### Hotspot 3: Auto-Prune Merged Branch Check (worktree-ops.sh, Lines 57-84)

**Code**:
```bash
is_worktree_stale() {
    local branch="$1"
    local worktree_path="$2"

    # Determine main branch name
    local main_branch
    main_branch=$(git config --get init.defaultBranch 2>/dev/null || echo "main")

    # Try main, fallback to master
    if ! git show-ref --verify --quiet "refs/heads/$main_branch" 2>/dev/null; then
        main_branch="master"
    fi

    # Check if branch is merged into main/master
    if git branch --merged "$main_branch" | awk -v b="$branch" '$0 ~ "^[* ]*" b "$" ...'; then
        # Check for uncommitted changes
        if ! status=$(git -C "$worktree_path" status --porcelain 2>/dev/null); then
            return 1
        fi
        ...
    fi
}
```

**Impact**:
- Called once per worktree during auto-prune
- For 10 worktrees: 10 × `git branch --merged` calls
- Plus 10 × `git status` calls

**Solution**: Cache branch merge status

---

## Worst Case Scenarios

### Scenario A: Large Repository + Many Branches + Interactive Mode

**Repository State**:
- 200 local branches
- 300 remote branches
- 50 worktrees
- Average worktree size: 1GB (with node_modules)

**User Action**: Open `git-wt` (no args) to browse branches

**Current Execution**:
1. generate_branch_list() called
   - `git branch --format=...` → returns 200 branches
   - `git branch -r --format=...` → returns 300 branches
   - Loop 1 (current branch): 1 × `has_worktree()` = 1 × `git worktree list --porcelain`
   - Loop 2 (with worktrees): 50 × `has_worktree()` = 50 × `git worktree list --porcelain`
   - Loop 3 (local without worktrees): 150 × `has_worktree()` = 150 × `git worktree list --porcelain`
   - Loop 4 (remote only): 300 × `has_worktree()` = 300 × `git worktree list --porcelain`
   
   **Total**: 502 × `git worktree list --porcelain` calls!

2. User selects branch and views preview
   - `find` + `stat` on 1GB worktree = several seconds
   - `du -sh` = several seconds
   - Additional git commands = fast

**Total Time**: 30+ seconds just to show fuzzy finder

### Scenario B: Auto-Prune with Many Stale Worktrees

**Repository State**:
- 100 worktrees, 30 are merged/stale

**User Action**: `git-wt` (triggers auto-prune in background)

**Current Execution**:
1. `git worktree list --porcelain` = 1 call
2. For each of 100 worktrees:
   - `git -C "$wt_path" branch --show-current` = 100 calls
3. For each stale candidate:
   - `git config --get init.defaultBranch` = up to 30 calls (could cache)
   - `git show-ref --verify --quiet` = up to 30 calls
   - `git branch --merged` = up to 30 calls
   - `git -C "$wt_path" status --porcelain` = up to 30 calls
4. Deletion:
   - `git worktree remove --force` = up to 30 calls
   - `du -sk` = up to 30 calls

**Total**: 200+ git commands for auto-prune

---

## Quick Reference: Function Call Graph

### Entry Points

```
git-wt (main)
├─ cmd_list()
│  └─ git worktree list (slow point: called in loop + once more in get_main_worktree)
│
├─ cmd_interactive()
│  ├─ generate_branch_list("local-only")
│  │  ├─ git branch --format (branches)
│  │  ├─ for each branch → has_worktree() → git worktree list --porcelain
│  │  └─ format_branch_line() → has_worktree() AGAIN
│  │
│  └─ fzf preview pane on selection
│     └─ show_worktree_info()
│        ├─ get_worktree_path() → git worktree list --porcelain
│        ├─ git -C ... status --porcelain
│        ├─ find + stat (for last modified) ← SLOW FILE I/O
│        ├─ du -sh (for size) ← SLOW FILE I/O
│        └─ git log (for commits)
│
└─ auto_prune_stale_worktrees()
   ├─ git worktree list --porcelain
   └─ for each worktree
      └─ is_worktree_stale()
         ├─ git config (for default branch)
         ├─ git show-ref (to verify branch exists)
         ├─ git branch --merged (to check if merged) ← EXPENSIVE
         └─ git -C ... status (to check uncommitted changes)
```


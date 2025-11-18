# Worktree Loading & Listing Performance Analysis

## Overview
The codebase has several performance bottlenecks related to loading and listing worktrees. This analysis identifies the specific functions, git commands, and operations that are causing performance issues.

---

## 1. Interactive Fuzzy Finder Mode (cmd_interactive)

### Location
- **File**: `/home/user/homebrew-git-wt/lib/fuzzy-finder.sh`
- **Function**: `cmd_interactive()` - Lines 431-551
- **Main async branch generator**: Lines 485-509 (in background process via FIFO)

### Git Commands Executed
1. **Initial branch loading** (Lines 487-508):
   - `git branch --show-current` - Get current branch
   - `git branch --format='%(refname:short)'` - List all local branches (repeated twice)
   - `git branch -r --format='%(refname:short)'` - List all remote branches

2. **For each branch in generate_branch_list()** (Lines 35-46):
   - `git branch --format='%(refname:short)'` 
   - `git branch -r --format='%(refname:short)'`

### Performance Bottleneck Details

#### Issue 1: Multiple calls to has_worktree() per branch
- **Function**: `format_branch_line()` - Lines 96-119
- **Called**: Multiple times per branch (4+ times in generate_branch_list)
- **Git commands per call**:
  - `git worktree list --porcelain` (Line 28 in worktree-ops.sh)
  - `git show-ref --verify --quiet "refs/heads/$branch"` (Line 22 in worktree-ops.sh)

**Code pattern** (fuzzy-finder.sh, Lines 62-70):
```bash
# Branch with worktree sorting loop - calls has_worktree() for EVERY branch
for branch_info in "${branches[@]}"; do
    local branch="${branch_info%|*}"
    local type="${branch_info#*|}"
    
    if [[ "$branch" != "$current_branch" ]] && has_worktree "$branch"; then  # ← GIT CALL
        formatted_branches+=("$(format_branch_line "$branch" "$type" "$current_branch")")
    fi
done
```

#### Issue 2: Repeated iteration over all branches
- **Location**: Lines 52-90
- **Iterations**: 4 separate loops over all branches
  1. Current branch (Line 57)
  2. Branches with worktrees (Line 67)
  3. Local branches without worktrees (Line 77)
  4. Remote-only branches (Line 87)
- **Each iteration calls**: `has_worktree()` → `git worktree list --porcelain` + `git show-ref`

### Data Gathered Per Worktree
- Whether worktree exists
- Branch type (local/remote)
- Presence of uncommitted changes (not in initial load, only in preview)

---

## 2. Preview Pane Information (show_worktree_info)

### Location
- **File**: `/home/user/homebrew-git-wt/lib/fuzzy-finder.sh`
- **Function**: `show_worktree_info()` - Lines 122-213

### Git Commands Executed (Per Branch Selected)
1. `git -C "$worktree_path" status --porcelain` (Line 146) - Git status
2. `git -C "$worktree_path" branch --show-current` (Line 107 in worktree-ops.sh, called from line 139) - Get branch
3. `git show-ref --verify --quiet "refs/heads/$branch"` (Line 189) - Check if local exists
4. `git ls-remote --heads origin "$branch"` (Line 194) - Check if remote exists
5. `git log --oneline --color=always -n 3 "$branch"` (Line 193) - Last 3 commits
6. `git log --oneline --color=always -n 3 "origin/$branch"` (Line 198) - Remote commits
7. `git branch --show-current` (Line 202) - Current branch

### Performance Bottleneck Details

#### Issue 1: Heavy file system operations in preview pane
- **Location**: Lines 154-177
- **Operations**:
  - `find` for most recently modified file (Lines 158, 161)
  - `stat` on all files excluding node_modules and .git (Lines 158, 161)
  - `du -sh` to calculate total worktree size (Line 171)
  - `du -sh node_modules` separately if it exists (Line 176)

**Code pattern** (Lines 156-162):
```bash
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS uses -f flag
    last_modified=$(find "$worktree_path" -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -exec stat -f "%m %N" {} \; 2>/dev/null | sort -rn | head -1 | awk '{print $1}')
else
    # Linux uses -c flag
    last_modified=$(find "$worktree_path" -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -exec stat -c "%Y %n" {} \; 2>/dev/null | sort -rn | head -1 | awk '{print $1}')
fi
```

#### Issue 2: Repeated conditional git calls
- **Location**: Lines 188-211
- **Problem**: Multiple separate git commands to determine branch type:
  1. `git show-ref --verify --quiet` to check if local
  2. `git ls-remote --heads origin` to check if remote
  3. Separate `git log` calls for local vs remote

### Data Gathered Per Worktree (In Preview)
- Git status (clean/dirty)
- Last modified timestamp
- Total directory size
- node_modules size
- Last 3 commits with full output
- Branch existence (local/remote/new)
- Recent modification time via `find` and `stat`

---

## 3. List Command (cmd_list)

### Location
- **File**: `/home/user/homebrew-git-wt/lib/commands.sh`
- **Function**: `cmd_list()` - Lines 130-169

### Git Commands Executed
- `git worktree list` (Line 143) - List all worktrees
- `get_main_worktree()` (Line 155) - Calls `git worktree list` again
- `get_project_name()` (Line 137) - Calls `git config --get remote.origin.url`

### Performance Bottleneck Details

#### Issue 1: Redundant git calls
- **Location**: Lines 143-168
- **Problem**: `git worktree list` is called once in the piped command, but `get_main_worktree()` calls it again
- **Code pattern**:
```bash
git worktree list | while IFS= read -r line; do
    local path=$(echo "$line" | awk '{print $1}')
    # ...
    if [[ "$path" == "$(get_main_worktree)" ]]; then  # ← CALLS GIT WORKTREE LIST AGAIN
        main_marker="${GREEN}[main]${NC} "
    fi
done
```

#### Issue 2: String processing for every worktree
- `awk` to extract path and branch
- `grep` to check for "(bare)"
- Comparison with main worktree path

### Data Gathered Per Worktree
- Path
- Branch name
- Whether it's main worktree
- Whether it's in managed worktrees directory

---

## 4. Auto-Prune Function (auto_prune_stale_worktrees)

### Location
- **File**: `/home/user/homebrew-git-wt/lib/worktree-ops.sh`
- **Function**: `auto_prune_stale_worktrees()` - Lines 87-136

### Git Commands Executed (Per Worktree)
1. `git worktree list --porcelain` (Line 129) - Get all worktrees
2. `git -C "$wt_path" branch --show-current` (Line 107) - Get branch for each worktree
3. `git branch --merged "$main_branch"` (Line 72 in is_worktree_stale) - Check if merged
4. `git show-ref --verify --quiet "refs/heads/$main_branch"` (Line 66) - Verify main branch exists
5. `git -C "$worktree_path" status --porcelain` (Line 75) - Check uncommitted changes
6. `git worktree remove --force` (Line 116) - Remove if stale

### Performance Bottleneck Details

#### Issue 1: Multiple git calls per worktree in is_worktree_stale()
- **Location**: `/home/user/homebrew-git-wt/lib/worktree-ops.sh`, Lines 57-84
- **Problem**: Called once per worktree to check if it should be pruned
- **Commands per check**:
  1. `git config --get init.defaultBranch` (Line 63)
  2. `git show-ref --verify --quiet "refs/heads/$main_branch"` (Line 66)
  3. `git branch --merged "$main_branch"` (Line 72) - Uses awk for literal matching

**Code pattern** (Lines 72-81):
```bash
if git branch --merged "$main_branch" 2>/dev/null | awk -v b="$branch" '$0 ~ "^[* ]*" b "$" {found=1} END {exit !found}'; then
    local status
    if ! status=$(git -C "$worktree_path" status --porcelain 2>/dev/null); then
        return 1
    fi
    if [[ -z "$status" ]]; then
        return 0  # Is stale and safe to prune
    fi
fi
```

#### Issue 2: Size calculation for reporting
- **Location**: Line 113
- **Command**: `du -sk "$wt_path"` for each deleted worktree
- **Problem**: Not needed if no pruning happens

### Data Gathered Per Worktree
- Current branch name
- Whether branch is merged into main
- Uncommitted changes status
- Worktree size (if being deleted)

---

## 5. Helper Functions Making Repeated Git Calls

### has_worktree()
- **Location**: `/home/user/homebrew-git-wt/lib/worktree-ops.sh`, Lines 15-33
- **Git Commands**:
  1. `git worktree list --porcelain` (Line 28)
  2. `git show-ref` - implicit in checking directory (Line 22)
- **Called From**: 
  - `format_branch_line()` (4+ times per branch generation cycle)
  - Fuzzy finder preview
  - Delete/recreate operations

### get_worktree_path()
- **Location**: `/home/user/homebrew-git-wt/lib/worktree-ops.sh`, Lines 38-54
- **Git Commands**:
  1. `git worktree list --porcelain` (Line 44)
- **Called From**:
  - `show_worktree_info()` (Line 139)
  - `delete_worktree_with_check()` (Line 260)
  - `delete_worktree_interactive()` (Line 317)
  - `recreate_worktree()` (Line 376)
  - `open_or_create_worktree()` (Line 229)

### get_main_worktree()
- **Location**: `/home/user/homebrew-git-wt/lib/git-utils.sh`, Lines 46-62
- **Git Commands**:
  1. `git worktree list` (Line 48)
- **Called From**:
  - `cmd_list()` (Line 155) - for each worktree
  - `auto_prune_stale_worktrees()` (Line 95)
  - `symlink_env_files()` - indirectly
  - `cmd_add()` (Line 21)
  - Various other functions

---

## Summary: Git Commands by Frequency

### Most Frequently Called Commands
1. **`git worktree list --porcelain`** - Called in:
   - has_worktree() - potentially hundreds of times during fuzzy finder
   - get_worktree_path() - hundreds of times
   - auto_prune_stale_worktrees() - once per session
   - Total: **Most expensive, called N times (where N = number of branches checked)**

2. **`git branch --format='%(refname:short)'`** - Called in:
   - generate_branch_list() - multiple times
   - fuzzy finder background process - at least 2 times
   - Total: **Called 2-3 times at startup**

3. **`git branch -r --format='%(refname:short)'`** - Called in:
   - generate_branch_list() - multiple times
   - fuzzy finder background process - at least 1 time
   - Total: **Called 1-2 times at startup**

4. **`git show-ref --verify --quiet "refs/heads/$branch"`** - Called in:
   - has_worktree() - indirectly through directory check
   - show_worktree_info() - once per preview

5. **`git branch --merged "$main_branch"`** - Called in:
   - is_worktree_stale() - once per worktree during auto-prune

### Heavy File System Operations
1. **`find` with `stat`** (show_worktree_info, Lines 158-162)
   - Scans entire worktree to find most recent file
   - Excludes node_modules and .git but still expensive

2. **`du -sh`** (show_worktree_info, Lines 171, 176)
   - Calculates total worktree size
   - Calculates node_modules size separately

---

## Caching Opportunities

### High Priority (Called Most Frequently)
1. **`git worktree list --porcelain`** → Cache entire output, invalidate on:
   - Any `git worktree add`
   - Any `git worktree remove`
   - Worktree operations

2. **`git branch --format='%(refname:short)'`** → Cache, invalidate on:
   - Any `git branch` creation/deletion
   - Repository changes

3. **`git branch -r --format='%(refname:short)'`** → Cache, invalidate on:
   - `git fetch`
   - Remote branch changes

### Medium Priority (Called Per Worktree)
4. **`git show-ref --verify --quiet`** → Cache existence checks

5. **`git branch --merged`** → Cache merged status, invalidate on branch updates

### Lower Priority (Heavy But Less Frequent)
6. **`find` + `stat` for last modified** → Cache per worktree
7. **`du -sh` for size** → Cache per worktree, invalidate on file changes

---

## Performance Impact Example

### Scenario: 20 branches, mixed local/remote, 5 with worktrees

**Current Performance (Without Caching):**
1. Load fuzzy finder:
   - `git branch --format=...` - 1 call
   - `git branch -r --format=...` - 1 call
   - `has_worktree()` for sorting - 20 calls × (1 `git worktree list --porcelain`)
   - **Total: 22+ git commands**

2. Select and preview one branch:
   - `git -C ... status --porcelain` - 1
   - `git ls-remote --heads origin` - 1
   - `git log` - 1-2
   - `find` with `stat` - 1 expensive operation
   - `du -sh` - 2 calls
   - **Total: 6-7 additional commands + heavy I/O**

3. Delete and reload:
   - `git worktree remove` - 1
   - `git __list-branches` regenerates entire list - 22+ commands again

**Total for typical workflow: 50+ git commands + multiple heavy I/O operations**

**With Caching:**
- Load fuzzy finder: 2-3 git commands (cached)
- Preview: 1-2 new commands (cached results reused)
- Delete and reload: 1 remove + 2-3 commands (refresh cached lists)

---

## Files to Modify for Caching Implementation

1. `/home/user/homebrew-git-wt/lib/worktree-ops.sh` - Add cache functions
2. `/home/user/homebrew-git-wt/lib/fuzzy-finder.sh` - Use cached branch list, update has_worktree
3. `/home/user/homebrew-git-wt/lib/commands.sh` - Cache in cmd_list()
4. `/home/user/homebrew-git-wt/git-wt` - Manage cache lifecycle

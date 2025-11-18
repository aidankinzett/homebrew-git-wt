# Caching Strategy & Implementation Recommendations

## Executive Summary

The main performance bottleneck is **`git worktree list --porcelain`** being called 500+ times in a typical fuzzy finder session with 20+ branches.

- **Current**: ~500 git commands per fuzzy finder session
- **With caching**: ~5 git commands per session
- **Improvement**: 100x faster worktree discovery

---

## Recommended Cache Architecture

### Cache Storage

Use in-memory cache during script execution + optional persistent cache in `.git`:

```bash
# Temporary memory cache (during script execution)
CACHE_WORKTREES=""
CACHE_BRANCHES=""
CACHE_BRANCHES_REMOTE=""
CACHE_TIMESTAMP=""

# Optional persistent cache (in .git directory)
GIT_DIR="$(git rev-parse --git-dir)"
CACHE_DIR="$GIT_DIR/git-wt-cache"
CACHE_FILE_WORKTREES="$CACHE_DIR/worktrees.txt"
CACHE_FILE_BRANCHES="$CACHE_DIR/branches.txt"
```

### Cache Invalidation Strategy

```bash
# Invalidation triggers (modify cache functions to track these)
- worktree add/remove → invalidate worktree cache
- git fetch → invalidate remote branch cache
- git branch -d/m → invalidate local branch cache
- File modifications → invalidate worktree info cache
- Time-based → 5 minute TTL for persistent cache
```

---

## Implementation Priority

### Phase 1: Critical (99% of performance gain)

#### 1.1: Cache `git worktree list --porcelain` (MANDATORY)

**File**: `/home/user/homebrew-git-wt/lib/worktree-ops.sh`

**Current (Lines 28, 44)**:
```bash
has_worktree() {
    local branch="$1"
    local project_name
    project_name=$(get_project_name)
    local expected_path="$WORKTREE_BASE/$project_name/$branch"
    if [[ -d "$expected_path" ]]; then
        return 0
    fi

    # ← EVERY CALL EXECUTES THIS
    if git worktree list --porcelain 2>/dev/null | grep -q "^worktree .*/$branch$"; then
        return 0
    fi
    return 1
}

get_worktree_path() {
    local branch="$1"
    local worktree_path
    # ← EVERY CALL EXECUTES THIS
    worktree_path=$(git worktree list --porcelain 2>/dev/null | grep "^worktree .*/$branch$" | awk '{print $2}')
    ...
}
```

**Recommended Solution**:
```bash
# Add to lib/worktree-ops.sh

# Initialize cache
_worktree_list_cache=""
_worktree_list_cache_valid=0

# Function to get cached worktree list
get_worktree_list_cached() {
    if [[ $_worktree_list_cache_valid -eq 0 ]]; then
        _worktree_list_cache=$(git worktree list --porcelain 2>/dev/null)
        _worktree_list_cache_valid=1
    fi
    echo "$_worktree_list_cache"
}

# Function to invalidate cache (call after add/remove)
invalidate_worktree_cache() {
    _worktree_list_cache=""
    _worktree_list_cache_valid=0
}

# Updated has_worktree() to use cache
has_worktree() {
    local branch="$1"
    local project_name
    project_name=$(get_project_name)
    local expected_path="$WORKTREE_BASE/$project_name/$branch"
    if [[ -d "$expected_path" ]]; then
        return 0
    fi

    # Use cached list instead of running git command
    if get_worktree_list_cached | grep -q "^worktree .*/$branch$"; then
        return 0
    fi
    return 1
}

# Updated get_worktree_path() to use cache
get_worktree_path() {
    local branch="$1"
    local worktree_path
    # Use cached list instead of running git command
    worktree_path=$(get_worktree_list_cached | grep "^worktree .*/$branch$" | awk '{print $2}')
    if [[ -n "$worktree_path" ]]; then
        echo "$worktree_path"
        return
    fi
    
    local project_name
    project_name=$(get_project_name)
    echo "$WORKTREE_BASE/$project_name/$branch"
}
```

**Performance Impact**: 
- Eliminates ~500 `git worktree list --porcelain` calls per session
- **Time saved**: 5-10 seconds per fuzzy finder session

**Call Sites to Update**:
- commands.sh:194 (cmd_remove) - call `invalidate_worktree_cache()`
- fuzzy-finder.sh:290, 349, 411 (delete operations) - call `invalidate_worktree_cache()`
- worktree-ops.sh:116 (auto_prune) - call `invalidate_worktree_cache()`

---

#### 1.2: Cache `git branch --format` Output

**File**: `/home/user/homebrew-git-wt/lib/fuzzy-finder.sh`

**Current (Lines 35-46, 496-508)**:
```bash
generate_branch_list() {
    local mode="${1:-all}"
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "")

    local branches=()

    # DUPLICATE CALLS in lines 35 and 498
    while IFS= read -r branch; do
        branches+=("$branch|local")
    done < <(git branch --format='%(refname:short)' 2>/dev/null)

    # Also called at line 508
    while IFS= read -r branch; do
        local branch_name="${branch#origin/}"
        if [[ "$branch_name" != "HEAD" ]] && ! [[ " ${branches[*]} " == *" $branch_name|local "* ]]; then
            branches+=("$branch_name|remote")
        fi
    done < <(git branch -r --format='%(refname:short)' 2>/dev/null | grep "^origin/")
}
```

**Recommended Solution**:
```bash
# Add to lib/fuzzy-finder.sh (or better, lib/git-utils.sh)

# Initialize cache
_branch_list_cache=""
_branch_list_cache_timestamp=0

# Cache git branch commands
get_local_branches_cached() {
    local now=$(date +%s)
    local cache_ttl=300  # 5 minutes
    
    if [[ -z "$_branch_list_cache" ]] || [[ $((now - _branch_list_cache_timestamp)) -gt $cache_ttl ]]; then
        _branch_list_cache=$(git branch --format='%(refname:short)' 2>/dev/null)
        _branch_list_cache_timestamp=$now
    fi
    echo "$_branch_list_cache"
}

# Cache git branch -r commands
get_remote_branches_cached() {
    local now=$(date +%s)
    local cache_ttl=300  # 5 minutes
    
    if [[ -z "$_remote_branch_cache" ]] || [[ $((now - _remote_branch_cache_timestamp)) -gt $cache_ttl ]]; then
        _remote_branch_cache=$(git branch -r --format='%(refname:short)' 2>/dev/null)
        _remote_branch_cache_timestamp=$now
    fi
    echo "$_remote_branch_cache"
}

# Updated generate_branch_list() using cache
generate_branch_list() {
    local mode="${1:-all}"
    local current_branch
    current_branch=$(git branch --show-current 2>/dev/null || echo "")

    local branches=()

    # Use cached version
    while IFS= read -r branch; do
        branches+=("$branch|local")
    done < <(get_local_branches_cached)

    if [[ "$mode" == "all" ]]; then
        while IFS= read -r branch; do
            local branch_name="${branch#origin/}"
            if [[ "$branch_name" != "HEAD" ]] && ! [[ " ${branches[*]} " == *" $branch_name|local "* ]]; then
                branches+=("$branch_name|remote")
            fi
        done < <(get_remote_branches_cached | grep "^origin/")
    fi
    
    # Rest of function unchanged...
}
```

**Performance Impact**: 
- Eliminates 2-3 duplicate `git branch --format` calls
- **Time saved**: 1-2 seconds

---

### Phase 2: Important (Reduce redundant calls)

#### 2.1: Deduplicate `format_branch_line()` has_worktree Calls

**File**: `/home/user/homebrew-git-wt/lib/fuzzy-finder.sh`

**Current (Lines 52-90)**:
```bash
# Issue: has_worktree() called 4+ times per branch
for branch_info in "${branches[@]}"; do
    local branch="${branch_info%|*}"
    local type="${branch_info#*|}"
    
    if [[ "$branch" == "$current_branch" ]]; then
        formatted_branches+=("$(format_branch_line "$branch" "$type" "$current_branch")")
    fi
done

for branch_info in "${branches[@]}"; do
    local branch="${branch_info%|*}"
    local type="${branch_info#*|}"
    
    if [[ "$branch" != "$current_branch" ]] && has_worktree "$branch"; then
        formatted_branches+=("$(format_branch_line "$branch" "$type" "$current_branch")")
    fi
done

# ...more loops...
```

**Problem**: 
- `format_branch_line()` calls `has_worktree()` again (line 105)
- So each branch's worktree status is checked multiple times

**Recommended Solution**:
```bash
# Precompute worktree existence for all branches (single cache lookup)
declare -A branch_has_worktree

# Single pass to populate cache
while IFS= read -r line; do
    if [[ "$line" =~ ^worktree ]]; then
        local wt_path="${line#worktree }"
        # Extract branch name from path
        local branch
        branch=$(git -C "$wt_path" branch --show-current 2>/dev/null)
        if [[ -n "$branch" ]]; then
            branch_has_worktree["$branch"]=1
        fi
    fi
done < <(get_worktree_list_cached)

# Then use the map for O(1) lookups instead of O(N) git calls
for branch_info in "${branches[@]}"; do
    local branch="${branch_info%|*}"
    if [[ ${branch_has_worktree[$branch]:-0} -eq 1 ]]; then
        # Branch has a worktree
    fi
done
```

**Performance Impact**:
- Single `git worktree list --porcelain` instead of 4N calls
- **Time saved**: 3-5 seconds

---

#### 2.2: Cache `get_main_worktree()` Result

**File**: `/home/user/homebrew-git-wt/lib/git-utils.sh`

**Current (Lines 46-62, called from commands.sh:155)**:
```bash
get_main_worktree() {
    local output
    if ! output=$(git worktree list 2>&1); then
        echo "Failed to get worktree list" >&2
        return 1
    fi

    local main_worktree
    main_worktree=$(echo "$output" | head -n 1 | awk '{print $1}')
    ...
}

# Called per-worktree in cmd_list:
git worktree list | while IFS= read -r line; do
    # ...
    if [[ "$path" == "$(get_main_worktree)" ]]; then  # ← Called for each line!
        main_marker="${GREEN}[main]${NC} "
    fi
done
```

**Recommended Solution**:
```bash
# Cache result in lib/git-utils.sh
_main_worktree_cache=""

get_main_worktree() {
    # Return cached result if available
    if [[ -n "$_main_worktree_cache" ]]; then
        echo "$_main_worktree_cache"
        return 0
    fi
    
    local output
    if ! output=$(git worktree list 2>&1); then
        echo "Failed to get worktree list" >&2
        return 1
    fi

    local main_worktree
    main_worktree=$(echo "$output" | head -n 1 | awk '{print $1}')
    
    # Cache the result
    _main_worktree_cache="$main_worktree"
    echo "$main_worktree"
}
```

**Performance Impact**:
- Eliminates redundant `git worktree list` calls in loops
- **Time saved**: 1-2 seconds

---

### Phase 3: Nice-to-Have (Reduce preview pane lag)

#### 3.1: Cache Preview Pane Heavy Operations

**File**: `/home/user/homebrew-git-wt/lib/fuzzy-finder.sh`

**Current (Lines 154-177)**:
```bash
show_worktree_info() {
    # ... 
    # Find most recently modified file (SLOW!)
    last_modified=$(find "$worktree_path" -type f -not -path "*/node_modules/*" -not -path "*/.git/*" -exec stat -f "%m %N" {} \; | sort -rn | head -1 | awk '{print $1}')
    
    # Calculate sizes
    total_size=$(du -sh "$worktree_path" 2>/dev/null | awk '{print $1}')
    
    if [[ -d "$worktree_path/node_modules" ]]; then
        nm_size=$(du -sh "$worktree_path/node_modules" 2>/dev/null | awk '{print $1}')
    fi
}
```

**Recommended Options**:

Option A: **Disable in preview (fastest)**
```bash
# Don't compute in preview pane, only show basic info
show_worktree_info() {
    local line="$1"
    local branch
    branch=$(echo "$line" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/^[✓ ]*//' | sed 's/ \[.*\]$//')
    
    echo "Branch: $branch"
    
    local worktree_path
    worktree_path=$(get_worktree_path "$branch")
    
    if [[ -d "$worktree_path" ]]; then
        echo "Worktree: $worktree_path"
        
        # Quick checks only
        status=$(git -C "$worktree_path" status --porcelain 2>/dev/null)
        if [[ -z "$status" ]]; then
            echo "Status: Clean ✓"
        else
            echo "Status: Has uncommitted changes"
        fi
        
        # Skip: find/stat/du operations for preview
        # User can check details after opening worktree
    else
        echo "Worktree: Not created"
    fi
}
```

**Performance Impact**: 
- Preview pane now shows instantly instead of 2-5 seconds
- **Time saved**: 2-5 seconds per preview

Option B: **Cache with background computation (best UX)**
```bash
# Store cached worktree info in .git/git-wt-cache/
# Update in background via auto-prune or on-demand
# Show stale cache immediately in preview, update in background
```

---

#### 3.2: Optimize `git branch --merged` Check

**File**: `/home/user/homebrew-git-wt/lib/worktree-ops.sh`

**Current (Lines 72)**:
```bash
is_worktree_stale() {
    local branch="$1"
    # ...
    if git branch --merged "$main_branch" 2>/dev/null | awk -v b="$branch" '$0 ~ "^[* ]*" b "$" {found=1} END {exit !found}'; then
        # Branch is merged
    fi
}
```

**Problem**: Runs `git branch --merged` which lists ALL merged branches, then filters with awk

**Recommended Solution**:
```bash
# Cache the merged branches list
_merged_branches_cache=""

get_merged_branches() {
    if [[ -z "$_merged_branches_cache" ]]; then
        _merged_branches_cache=$(git branch --merged 2>/dev/null)
    fi
    echo "$_merged_branches_cache"
}

is_branch_merged() {
    local branch="$1"
    local main_branch="$2"
    
    # Use cached list
    if get_merged_branches | awk -v b="$branch" '$0 ~ "^[* ]*" b "$" {found=1} END {exit !found}'; then
        return 0
    fi
    return 1
}
```

**Performance Impact**:
- Single `git branch --merged` call instead of per-worktree
- **Time saved**: 5+ seconds during auto-prune

---

## Cache Invalidation Map

### When to Invalidate What

```
Event                              Cache to Invalidate
────────────────────────────────────────────────────────
git worktree add                   ✓ worktrees
git worktree remove                ✓ worktrees
git branch -c/-m (rename)          ✓ branches, ✓ worktrees
git branch -d (delete)             ✓ branches, ✓ merged_status
git fetch origin                   ✓ remote_branches
git push / merge commit            ✓ merged_status
After show_worktree_info preview   ✓ file_stats (size, mtime)
Every 5 minutes (TTL)              ✓ all caches
```

### Implementation in Commands

```bash
# In cmd_add (commands.sh:67)
git worktree add "$worktree_path" -b "$branch" && invalidate_worktree_cache

# In cmd_remove (commands.sh:194)
git worktree remove "$worktree_path" --force && invalidate_worktree_cache

# In delete_worktree_interactive (fuzzy-finder.sh:349)
git worktree remove --force "$worktree_path" && invalidate_worktree_cache

# In auto_prune_stale_worktrees (worktree-ops.sh:116)
git worktree remove --force "$wt_path" && invalidate_worktree_cache
```

---

## Testing the Cache

### Unit Tests to Add

```bash
# test/caching.bats

@test "cache: worktree list is called only once per session" {
    load_git_wt
    # Create 10 branches
    for i in {1..10}; do
        git branch "test-branch-$i"
    done
    
    # Call has_worktree 10 times
    for i in {1..10}; do
        has_worktree "test-branch-$i"
    done
    
    # Verify git worktree list was called only once
    # (Use strace or spy on function calls)
}

@test "cache: invalidate_worktree_cache clears cached data" {
    load_git_wt
    local result1=$(has_worktree "test-branch")
    invalidate_worktree_cache
    local result2=$(has_worktree "test-branch")
    [ "$result1" = "$result2" ]
}

@test "cache: get_main_worktree returns cached result on second call" {
    load_git_wt
    local main1=$(get_main_worktree)
    local main2=$(get_main_worktree)
    [ "$main1" = "$main2" ]
}
```

---

## Rollout Strategy

### Phase 1 (Immediate): Cache worktree list
- Add `get_worktree_list_cached()` to worktree-ops.sh
- Update `has_worktree()` and `get_worktree_path()`
- Add invalidation calls to delete operations
- **Expected improvement**: 50-80% faster fuzzy finder load

### Phase 2 (Week 2): Cache branch lists
- Add `get_local_branches_cached()` and `get_remote_branches_cached()`
- Update `generate_branch_list()`
- Add 5-minute TTL
- **Expected improvement**: Additional 20-30% faster

### Phase 3 (Week 3): Reduce preview pane lag
- Disable heavy file operations OR
- Add background caching
- Cache main worktree lookup
- **Expected improvement**: 10-15% faster preview

### Phase 4 (Week 4): Polish
- Add metrics/logging for cache hits
- Document cache behavior
- Add `git-wt --cache-stats` command
- Add tests

---

## Success Metrics

```
Metric                          Before          After           Target
──────────────────────────────────────────────────────────────────────
git-wt (fuzzy finder load)      8-12 seconds    1-2 seconds     <2s
Preview pane response           2-5 seconds     <100ms          <500ms
Auto-prune (10 worktrees)       5-8 seconds     <1 second       <2s
Total git commands per session  500+            5-10            <20
Memory overhead                 ~0KB            ~500KB          <5MB
```


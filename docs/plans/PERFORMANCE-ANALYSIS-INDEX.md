# Worktree Loading Performance Analysis - Index

## Overview

This directory contains a comprehensive performance analysis of the worktree loading and listing operations in `git-wt`. The analysis identifies critical bottlenecks and provides implementation recommendations for a caching solution.

**Key Finding**: The main bottleneck is `git worktree list --porcelain` being called 500+ times per fuzzy finder session when iterating over 20+ branches.

---

## Documents

### 1. [worktree-loading-performance-analysis.md](./worktree-loading-performance-analysis.md) (13KB)

**Purpose**: Deep dive into current performance bottlenecks

**Contents**:
- Overview of all worktree loading operations
- Detailed analysis of each operation (functions, line numbers, git commands)
- Commands executed per operation
- Data gathered per worktree
- Performance impact examples
- Files to modify

**Key Sections**:
- Interactive Fuzzy Finder Mode (cmd_interactive) - Lines 431-551
- Preview Pane Information (show_worktree_info) - Lines 122-213
- List Command (cmd_list) - Lines 130-169
- Auto-Prune Function (auto_prune_stale_worktrees) - Lines 87-136
- Helper functions with repeated git calls

**Read This If**:
- You need to understand the current architecture
- You want specific function names and line numbers
- You need to know which git commands are slow

---

### 2. [git-commands-reference.md](./git-commands-reference.md) (9.1KB)

**Purpose**: Master reference of all git commands and their call frequencies

**Contents**:
- Complete list of all git commands ranked by frequency
- Non-git heavy operations (find, stat, du)
- Three critical hotspots with code examples
- Worst-case scenarios
- Function call graph

**Tables**:
- 21 git commands with locations, callers, and frequencies
- Heavy file system operations
- Hotspot analysis with code patterns

**Worst Case Scenarios**:
- 200 local branches + 300 remote + 50 worktrees = 502+ git commands
- Auto-prune with 100 worktrees and 30 stale = 200+ git commands

**Read This If**:
- You want a quick reference of which git commands are called most
- You need to understand call frequency and impact
- You want to see worst-case scenarios

---

### 3. [caching-strategy-recommendations.md](./caching-strategy-recommendations.md) (17KB)

**Purpose**: Detailed caching implementation plan with code examples

**Contents**:
- Recommended cache architecture (in-memory + persistent)
- Cache invalidation strategy
- Phased implementation plan (4 phases)
- Code snippets for each cache function
- Testing strategy
- Rollout plan
- Success metrics

**Phases**:
1. **Critical** (Phase 1) - Cache `git worktree list --porcelain` (99% of gain)
2. **Important** (Phase 2) - Cache branch lists, deduplicate calls
3. **Nice-to-Have** (Phase 3) - Reduce preview pane lag
4. **Polish** (Phase 4) - Metrics, logging, documentation

**Expected Performance Gains**:
- Fuzzy finder load: 8-12 seconds → 1-2 seconds (80-90% faster)
- Preview pane: 2-5 seconds → <100ms (95% faster)
- Auto-prune: 5-8 seconds → <1 second (87% faster)
- Total git commands: 500+ → 5-10 (98% reduction)

**Read This If**:
- You're implementing the caching solution
- You need specific code examples
- You want to understand the phased approach
- You need to plan the rollout

---

## Quick Reference

### Most Critical Bottleneck
**Location**: `/home/user/homebrew-git-wt/lib/fuzzy-finder.sh`, Lines 52-90

**Issue**: 4 loops over all branches, each calling `has_worktree()`, which calls `git worktree list --porcelain`

**Impact**: For 20 branches = 80 git commands (each taking 50-100ms)

**Solution**: Cache `git worktree list --porcelain` output and create lookup map

**Implementation Time**: ~30 minutes

---

### Second Most Critical Bottleneck
**Location**: `/home/user/homebrew-git-wt/lib/fuzzy-finder.sh`, Lines 154-177

**Issue**: `find` with `stat` to find most recently modified file in entire worktree

**Impact**: 2-5 seconds per preview pane display

**Solution**: Disable in preview or cache with background computation

**Implementation Time**: ~20 minutes

---

### Third Most Critical Bottleneck
**Location**: `/home/user/homebrew-git-wt/lib/worktree-ops.sh`, Lines 57-84

**Issue**: `git branch --merged` called once per worktree during auto-prune

**Impact**: For 30 stale worktrees = 30 redundant git commands

**Solution**: Cache `git branch --merged` output

**Implementation Time**: ~20 minutes

---

## Files Needing Modification

| File | Changes | Priority |
|------|---------|----------|
| lib/worktree-ops.sh | Add caching functions, update has_worktree(), get_worktree_path() | P0 |
| lib/fuzzy-finder.sh | Use cached worktree list, fix loop redundancy, optimize preview | P0 |
| lib/git-utils.sh | Cache get_main_worktree() | P1 |
| commands.sh | Call cache invalidation after modifications | P0 |
| test/caching.bats | Add cache unit tests | P2 |

---

## How to Use These Documents

### For Project Managers
1. Start with **git-commands-reference.md** to understand scale of problem
2. Review **caching-strategy-recommendations.md** for timeline and phases
3. Use "Success Metrics" section for acceptance criteria

### For Developers
1. Start with **worktree-loading-performance-analysis.md** for context
2. Deep dive into **caching-strategy-recommendations.md** for implementation
3. Reference **git-commands-reference.md** for specific line numbers

### For Code Reviewers
1. Check **git-commands-reference.md** to verify no git commands are missed
2. Review **caching-strategy-recommendations.md** for correctness of implementation
3. Validate against **worktree-loading-performance-analysis.md** test cases

---

## Performance Targets

| Metric | Current | Target | Priority |
|--------|---------|--------|----------|
| Fuzzy finder startup | 8-12s | <2s | P0 |
| Preview pane response | 2-5s | <500ms | P0 |
| Auto-prune (10 worktrees) | 5-8s | <2s | P1 |
| Total git commands/session | 500+ | <20 | P0 |
| Memory overhead | 0KB | <5MB | P2 |

---

## Implementation Checklist

- [ ] Read all three analysis documents
- [ ] Set up local test environment with 20+ branches
- [ ] Implement Phase 1 caching (worktree list)
- [ ] Measure performance improvement
- [ ] Add unit tests for cache functions
- [ ] Implement cache invalidation
- [ ] Implement Phase 2 (branch list caching)
- [ ] Optimize preview pane (Phase 3)
- [ ] Add cache metrics/logging (Phase 4)
- [ ] Update documentation
- [ ] Performance benchmarking before/after
- [ ] Code review

---

## Related Documents

- [2025-10-21-git-wt-enhancements-design.md](./2025-10-21-git-wt-enhancements-design.md) - Overall design for fuzzy finder and auto-pruning

---

## Questions?

Refer to the specific document sections:
- **"Why is X slow?"** → worktree-loading-performance-analysis.md
- **"How many times is X called?"** → git-commands-reference.md  
- **"How do I implement Y?"** → caching-strategy-recommendations.md

---

Generated: 2025-11-18
Last Updated: 2025-11-18

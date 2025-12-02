# Versioning System Design

**Date:** 2025-12-02
**Status:** Approved

## Overview

Add version tracking to git-wt to help users understand what changed between updates, while maintaining the current HEAD-only installation model.

## Requirements

### Primary Goal
Help users track changes when they run `brew upgrade --fetch-HEAD git-wt` by providing:
- Clear version numbers for reference
- Changelog documenting what changed
- Easy way to check current version

### Constraints
- Stay HEAD-only (no stable releases yet)
- Maintain simplicity of current installation workflow
- Follow standard CLI conventions

### Success Criteria
- Users can run `git-wt --version` to see current version
- Version appears in `--help` output
- CHANGELOG.md provides clear change history
- CLAUDE.md documents version update workflow

## Design

### Version Storage and Display

**Version Declaration:**
```bash
# Near top of git-wt script (after header comments, before library sourcing)
VERSION='0.1.0'
```

**Version Helper Function:**
```bash
get_version() {
    local version="$VERSION"
    # Append git commit SHA if available (useful for HEAD installations)
    if git rev-parse --git-dir > /dev/null 2>&1; then
        local sha=$(git rev-parse --short HEAD 2>/dev/null)
        if [[ -n "$sha" ]]; then
            version="$version ($sha)"
        fi
    fi
    echo "$version"
}
```

**Display Implementation:**
1. Add `--version | -v` flag handler:
   ```bash
   if [[ "$1" == "--version" || "$1" == "-v" ]]; then
       get_version
       exit 0
   fi
   ```

2. Update help text to show version at top:
   ```bash
   echo "git-wt v$(get_version) - Interactive git worktree manager"
   ```

**Output Examples:**
- Without git: `0.1.0`
- With git: `0.1.0 (abc1234)`
- Help: `git-wt v0.1.0 - Interactive git worktree manager`

### Changelog Structure

**File:** `CHANGELOG.md` (repository root)

**Format:** Keep a Changelog (https://keepachangelog.com)

**Structure:**
```markdown
# Changelog

All notable changes to git-wt will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Added
### Changed
### Fixed

## [0.1.0] - 2025-12-02
### Added
- Interactive fuzzy finder with fzf integration
- Automatic package manager detection (pnpm/yarn/npm)
- Environment file symlinking from main worktree
- Editor integration (Cursor, VS Code, Agy)
- Configurable worktree base path
- Auto-pruning of merged branches
- Version tracking with --version flag
- CHANGELOG.md following Keep a Changelog format
```

**Categories (use as needed):**
- **Added**: New features
- **Changed**: Changes to existing functionality
- **Deprecated**: Soon-to-be removed features
- **Removed**: Removed features
- **Fixed**: Bug fixes
- **Security**: Security fixes

### Versioning Scheme

**Format:** Semantic Versioning (https://semver.org)

**Current:** 0.MINOR.PATCH (pre-1.0 development)

**Guidelines:**
- **0.MINOR.x**: New features, significant changes
- **0.x.PATCH**: Bug fixes, small improvements
- Stay in 0.x.x until API is considered stable
- Move to 1.0.0 when ready for production stability commitment

### Documentation Updates

**CLAUDE.md additions:**

1. Add new "Version Management" section under "Development Commands":

```markdown
### Version Management

**Current version system: HEAD-only with embedded versioning**

The project uses SemVer (0.MINOR.PATCH) with versions embedded in the script.

**Checking current version:**
```bash
./git-wt --version
# Shows: 0.1.0 (abc1234) if in git repo
# Shows: 0.1.0 if not in git repo
```

**Updating the version:**

1. Update VERSION variable in `git-wt` script (line ~7)
2. Update CHANGELOG.md:
   - Move items from [Unreleased] to new [X.Y.Z] section
   - Add release date
   - Create new empty [Unreleased] section
3. Commit changes: `git commit -m "Bump version to X.Y.Z"`
4. Push to main

Users will get the update on next `brew reinstall git-wt` or `brew upgrade --fetch-HEAD git-wt`

**Versioning scheme:**
- MAJOR.MINOR.PATCH (SemVer)
- Stay in 0.x.x until API is stable
- MINOR: New features, significant changes
- PATCH: Bug fixes, small improvements
```

2. Update "Versioning Strategy" section to reflect implemented versioning

## Implementation Checklist

- [ ] Add VERSION constant to git-wt script
- [ ] Add get_version() helper function
- [ ] Add --version flag handler
- [ ] Update --help text to show version
- [ ] Create CHANGELOG.md with Keep a Changelog format
- [ ] Document current features in [0.1.0] section
- [ ] Add "Version Management" section to CLAUDE.md
- [ ] Update "Versioning Strategy" in CLAUDE.md
- [ ] Commit versioning system
- [ ] Update README.md if needed

## Future Considerations

### Stable Releases (when ready)
When moving to stable releases:
1. Create git tags: `git tag v0.2.0`
2. Update Homebrew formula with `url` and `sha256`
3. Users can install without --HEAD flag
4. See CLAUDE.md "Versioning Strategy" for full workflow

### Automation Opportunities
- Script to bump version and update changelog
- Git hooks to verify changelog is updated
- GitHub Actions to validate version consistency

## Trade-offs

**Chosen Approach (Hybrid with git metadata):**
- ✅ Clear semantic version for users
- ✅ Git SHA helps debug HEAD installations
- ✅ No extra files to maintain
- ✅ Works both in and out of git repos
- ⚠️ Manual version updates required
- ⚠️ Slightly more complex version display logic

**Rejected Alternatives:**
1. **Separate VERSION file**: Adds extra file, no significant benefit
2. **Git tag-based versioning**: Too complex for HEAD-only model
3. **Simple version variable only**: Loses git SHA benefit for debugging

## Questions and Decisions

**Q: Why start at 0.1.0 instead of 1.0.0?**
A: The tool is still evolving with planned features. 0.x.x signals pre-production.

**Q: Why Keep a Changelog format?**
A: Industry standard, well-structured, familiar to users.

**Q: Why show git SHA in version?**
A: HEAD installations mean every user may be on different commits. SHA helps with debugging.

**Q: Why not add stable releases now?**
A: Staying HEAD-only reduces complexity. Can add stable releases later when needed.

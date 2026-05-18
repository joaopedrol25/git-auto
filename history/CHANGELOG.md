# Changelog — gitauto

All notable changes to `gitauto` (formerly `git-auto`) are documented here.
Versions correspond to branches pushed to the remote repository.

---

## v2.0 — Current (branch: `main`)

**Renamed command:** `git-auto` → `gitauto`

### Added
- `gitauto -a / --stage-all` — runs `git add -A` and then the full standard flow in one shot
- `r / retry` option at the commit prompt — regenerates the AI message without restarting
- `--undo` now shows **author** and **relative timestamp** ("2 hours ago") of the last commit
- `check_git_repository` is now called first in the `--stage-all` flow, before staging

### Changed
- Binary installed as `/usr/local/bin/gitauto` (replaces `/usr/local/bin/git-auto`)
- All user-facing strings and help text updated to `gitauto`
- Help menu aligned and reformatted for consistency
- `push_choice` now defaults to `y` when Enter is pressed in the push prompt

### Internal
- Snapshot saved as `history/v2.0.sh`

---

## v1.2 — (branch: `origin/v1.2`)

### Added
- `gitauto -u / --undo` — safe undo/revert of the last commit
  - Detects whether the commit is local-only or already pushed
  - Local: runs `git reset --soft HEAD~1`, keeps changes staged
  - Pushed: offers **Revert** (new commit) or **Force** (rewrite history)
- `gitauto -h / --help` — help menu listing all available flags
- CLI argument parsing via a `case` block at the bottom of the script
- `get_current_branch` and `get_current_remote` now used inside `undo_last_commit`

### Changed
- Entry point moved from bare function calls to a `case "${1:-}"` block
- `e / edit` option in the commit prompt now defaults input to an empty guard

### Internal
- Snapshot saved as `history/v1.2.sh`

---

## v1.1 — (branch: `origin/v1.1`)

### Added
- `check_api_key` — validates `API_KEY_AI` is set before making any network call
- `check_staged_changes` — if nothing is staged, asks the user if they want to push anyway
- `do_commit` — interactive commit prompt: accept (`Y`), reject (`n`), or edit (`e`) the AI message
- `push_to_remote` — detects the current branch and remote, asks before pushing
- `get_current_branch` / `get_current_remote` — helper functions for branch/remote detection
- HTTP status code check on the API response (exits on non-200)
- Diff is now limited to 300 lines (`head -n 300`) to avoid token overflow

### Changed
- Script fully refactored into functions (from a flat procedural script in v1.0)
- API endpoint updated to `gemini-flash-latest` (from `gemini-3-flash-preview`)
- Commit message prompt improved with a colon-prefix convention and an example
- Diff is passed to the API via `env.DIFF_CONTENT` (exported variable) instead of `--arg`

### Internal
- Snapshot saved as `history/v1.1.sh`

---

## v1.0 — Initial release

### Added
- Basic bash script that reads `git diff --cached` and sends it to Gemini AI
- Commits automatically with the AI-generated message (no confirmation prompt)
- No push support
- No API key validation
- No function structure — single flat script

### Notes
- Used `gemini-3-flash-preview` as the model endpoint
- No HTTP error checking on the API response
- Diff was passed in full with no size limit

### Internal
- Snapshot saved as `history/v1.0.sh`

---

## Snapshots

| File | Version | Branch |
|------|---------|--------|
| `history/v1.0.sh` | v1.0 | Initial commit (`92eecd5`) |
| `history/v1.1.sh` | v1.1 | `origin/v1.1` (`825f2dd`) |
| `history/v1.2.sh` | v1.2 | `origin/v1.2` (`30075cb`) |
| `history/v2.0.sh` | v2.0 | `main` (current) |

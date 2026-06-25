# better-headroom Governance

This document defines the governance procedures for maintaining the `better-headroom` fork — how to make changes, sync with upstream, rebase feature branches, build, and push.

For an overview of the fork's purpose and features, see [BETTER-HEADROOM.md](./BETTER-HEADROOM.md).

---

## Fork Structure

```
                      upstream/headroomlabs-ai/headroom
                      ┌─────────────────────────┐
                      │  main (development)     │◀── upstream target, changes over time
                      └─────────────────────────┘
                                │
                                │ fork
                                ▼
                oleksii-honchar/better-headroom (origin)
                ┌─────────────────────────────────────┐
                │  main (mirrors upstream/main)       │◀── kept current
                │  patched/main (working branch)      │◀── patches + synced with upstream
                │  feat-provider-fallback...          │◀── feature branches off patched/main
                └─────────────────────────────────────┘
```

**Key rules:**
- **`main`** — Mirrors upstream/main. Kept current via periodic sync.
- **`patched/main`** — Your working branch. Contains patches + synced with upstream.
- **Feature branches** — Branch off `patched/main`. Rebased onto `patched/main` before merge.
- **`origin`** — Your fork (push target). NOT the original repo.
- **`upstream`** — Original repo (read-only, never push).

---

## Core Principle: Preserve Our Features

**Our features are the highest priority.** When resolving any merge or rebase conflict:

1. **Always preserve our feature code** — if a conflict exists between our changes and upstream changes, our feature logic wins.
2. **Adapt to upstream structural changes** — if upstream changed APIs, types, or patterns, adapt our feature code to the new upstream patterns while preserving its behavior.
3. **Never discard our feature changes** — do NOT use `-X theirs` or blindly accept upstream's version when our feature code is involved.
4. **If unsure, keep both** — include both our code and upstream's code, then clean up manually.

This principle applies to:
- Rebase conflicts on `patched/main` onto upstream/main
- Rebase conflicts on feature branches onto `patched/main`
- Merge conflicts when integrating feature branches into `patched/main`

---

## Syncing with Upstream (Staying Current)

**Before making any changes, always sync first:**

```bash
cd ~/www/misc/better-headroom

# 1. Fetch latest from both remotes
git fetch upstream main --quiet
git fetch origin --quiet

# 2. Check divergence
git log --oneline patched/main..upstream/main | wc -l  # commits behind
git log --oneline upstream/main..patched/main | wc -l  # commits ahead

# 3. Rebase patched/main onto upstream/main
git checkout patched/main
git rebase upstream/main

# 4. If conflicts occur, resolve them (preserve our features!):
#    - Edit conflicted files — keep our feature code, adapt to upstream changes
#    - git add <resolved-file>
#    - git rebase --continue      (after resolving each conflict)
#    - git rebase --abort         (to cancel)

# 5. Push rebased branch to your fork
git push origin patched/main --force-with-lease
```

---

## Rebase Workflow for Feature Branches

Feature branches are created from `patched/main` and must be rebased onto `patched/main` before they are merged back. This ensures a linear history and that our features stay on top of the latest upstream + patches.

### Step 1: Create a feature branch from `patched/main`

```bash
cd ~/www/misc/better-headroom

# Ensure patched/main is up to date (sync with upstream first if needed)
git checkout patched/main
git pull origin patched/main

# Create feature branch
git checkout -b feat-provider-fallback

# Make your changes...
# ...

# Commit and push
git add .
git commit -m "feat: describe your change"
git push origin feat-provider-fallback
```

### Step 2: Rebase feature branch onto `patched/main` (before merge)

```bash
cd ~/www/misc/better-headroom

# 1. Make sure patched/main is current
git checkout patched/main
git pull origin patched/main

# 2. Switch to feature branch
git checkout feat-provider-fallback

# 3. Rebase onto patched/main
git rebase patched/main

# 4. Resolve any conflicts:
#    - Our feature code is the priority — preserve it
#    - Adapt to upstream structural changes if needed
#    - git add <resolved-file>
#    - git rebase --continue

# 5. Force-push the rebased branch
git push origin feat-provider-fallback --force-with-lease
```

### Step 3: Merge feature branch into `patched/main`

```bash
git checkout patched/main
git merge feat-provider-fallback --no-ff
git push origin patched/main
```

Use `--no-ff` to preserve the feature branch as a distinct merge commit in history.

---

## Building and Testing

**Build with maturin:**
```bash
cd ~/www/misc/better-headroom
maturin build --release
```

**Install in editable mode (for development):**
```bash
./build-and-install.sh --install-editable
```

**Build a wheel (for distribution):**
```bash
./build-and-install.sh --build-wheel
```

**Install from wheel:**
```bash
./build-and-install.sh --install-wheel
```

**Run tests:**
```bash
cd ~/www/misc/better-headroom
pytest tests/test_observability_metrics.py -v
```

**Verify the build:**
```bash
python -c "import headroom; print(headroom.__version__)"
```

---

## Pushing Changes to GitHub

**After making local changes:**
```bash
cd ~/www/misc/better-headroom
git push origin patched/main
```

**If you need to force push (after rebase):**
```bash
git push origin patched/main --force-with-lease
```

---

## Recovery Scenarios

| Problem | Solution |
|---------|----------|
| Rebase fails with conflicts | Resolve conflicts (preserve our features!), `git rebase --continue` |
| Rebase is too messy to continue | `git rebase --abort` to reset, then resolve manually |
| Accidentally lost our feature code in conflict | Check `git reflog` to recover, or re-apply from feature branch |
| Fork is far behind upstream | Run sync steps above, resolve conflicts iteratively |
| maturin build fails | Check Rust toolchain, ensure `rust-toolchain.toml` is satisfied |

---

## Common Mistakes to Avoid

- **Don't push to `upstream`** — `upstream` is read-only. Always push to `origin`.
- **Don't add patches to `main`** — `main` mirrors upstream/main. Use `patched/main` for your work.
- **Don't use `-X theirs` with local patches** — It will discard your changes on conflict.
- **Don't forget to fetch `origin/patched/main`** — Your fork's remote may have updates you haven't seen.
- **Don't merge feature branches without rebasing first** — Always rebase onto `patched/main` before merging to avoid unnecessary merge commits.

---

## Verification Commands

```bash
# Verify remotes are correct
git remote -v
# origin → oleksii-honchar/better-headroom.git (your fork)
# upstream → headroomlabs-ai/headroom.git (original)

# Verify current branch
git branch --show-current
# Should show: patched/main

# Verify divergence
git log --oneline origin/patched/main..patched/main | wc -l  # commits ahead
git log --oneline patched/main..origin/patched/main | wc -l  # commits behind

# Verify headroom package version
python -c "import headroom; print(headroom.__version__)"

# Verify provider fallback
python -c "from headroom.observability.metrics import Metrics; print(Metrics.create_metric.__defaults__)"
```

---

## Runtime Dependencies — Auto-installed

The `build-and-install.sh` script auto-installs required dependencies if missing:

- **Rust** — installed via rustup (if not already present)
- **maturin** — installed via pip into the project venv

The script also creates and uses a `.venv` virtual environment automatically.

```bash
# Just run the script — it installs everything needed
./build-and-install.sh --install-editable
```

**Manual install (if needed):**

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env

# Install maturin
pip install maturin

# Verify
rustc --version
maturin --version
```

---

## License

MIT — Same as upstream headroom.

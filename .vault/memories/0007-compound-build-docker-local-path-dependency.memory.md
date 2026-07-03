---
type: memory
title: "Compound Docker build required for local path dependencies — --frozen ignores local paths"
createdAt: "2026-06-30T14:00:00Z"
updatedAt: "2026-06-30T14:00:00Z"
tags: [docker, uv, gotcha, build, local-dependency, pyo3]
see_also: []
deprecated:
  date: null
  reason: null
  superseded_by: null
---

# Memory: Compound Docker build required for local path dependencies

## Fact

When better-litellm depends on a local path to better-headroom (`headroom-ai = { path = "../better-headroom" }`), Docker builds fail to pick up local changes because the path lies outside the Docker build context, and `--frozen` flag causes uv to use the lockfile (which resolves from PyPI).

## Context

**Symptoms:**
- `uv lock` resolves `headroom-ai` from PyPI (v0.26.0) instead of local path (v0.27.0)
- Docker build uses PyPI version, ignoring local changes
- `--frozen` flag enforces lockfile, preventing re-resolution

**Solution: Compound build pattern:**

```dockerfile
# Copy local dep source into build context
COPY better-headroom/ ./better-headroom/

# Remove --frozen so uv re-resolves from local path
COPY pyproject.toml uv.lock ./
RUN uv sync ...  # NOT --frozen
```

**Required rsync exclusions before COPY:**
```bash
rsync -a --exclude='target' --exclude='.venv' --exclude='__pycache__' \
  --exclude='*.pyc' --exclude='dist' --exclude='agent-evals' \
  --exclude='tests' --exclude='e2e' --exclude='docker' --exclude='.git' \
  /path/to/better-headroom/ \
  /path/to/better-litellm/better-headroom/
```

**Required inclusions:** `crates/` (Rust source for pyo3 wheel build), `src/`, `pyproject.toml`

## Impact

- Any compound build with local path dependencies requires this pattern
- `--frozen` + local path = PyPI version used (wrong)
- Without `crates/`, pyo3 wheel build fails (better-headroom has Rust bindings)
- This pattern generalizes to any monorepo with Dockerized services depending on sibling packages

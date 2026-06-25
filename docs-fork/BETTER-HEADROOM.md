# better-headroom

## Purpose

A maintained fork of [headroom](https://github.com/headroomlabs-ai/headroom) that patches critical gaps in the AI observability agent:

1. **Provider attribute missing from metrics** — When `provider=None`, metrics lose their source attribution. The fix defaults provider to `"local"` in key methods and the pipeline, ensuring every metric always carries a provider attribute.

This fork provides a provider fallback guarantee that metrics are never orphaned without a provider.

---

## Features

The fork adds one critical fix to ensure metrics always carry provider attribution:

- **Provider Fallback Fix (spec/001)** — When `provider=None`, default to `"local"` in `Metrics` methods and `Pipeline`. Prevents metrics from being recorded without provider attribution.

See **[FEATURES.md](./docs-fork/FEATURES.md)** for detailed descriptions and configuration.

---

## Installation

### Prerequisites

- **macOS** (Apple Silicon recommended)
- **Python 3.11+** — for the virtual environment
- **Git** — for fetching and building

> **Note:** maturin and Rust are auto-installed by the build script if missing.
> The build uses `--no-deps` since headroom's `litellm>=1.86.2` can't be resolved from PyPI (1.83.9 max) — the litellm dependency is lazy and resolved by the consuming project (better-litellm).

### Quick Install (Recommended)

```bash
# Clone the fork (if not already cloned)
cd ~/www/misc
git clone git@github.com:oleksii-honchar/better-headroom.git

# Build and install (automates everything)
cd better-headroom
./build-and-install.sh --install-editable
python -c "import headroom; print(headroom.__version__)"
```

This script will:
1. Fetch the latest upstream `main` branch
2. Rebase `patched/main` onto upstream
3. Build with `maturin build --release`
4. Install the forked package in editable mode

---

## Usage

### Using the Forked Package

```bash
# Install in editable mode for development
./build-and-install.sh --install-editable

# Build a wheel for distribution
./build-and-install.sh --build-wheel

# Install from wheel
./build-and-install.sh --install-wheel
```

### Integration with better-litellm

The fork is integrated as a local path dependency in better-litellm:

```toml
# better-litellm/pyproject.toml
[project]
dependencies = [
    "headroom-ai[proxy]",
]

[tool.uv.sources]
headroom-ai = { path = "../better-headroom" }
```

---

## Runbook: Making Changes and Syncing with Source

For detailed governance procedures — fork structure, syncing with upstream, making changes, building, and pushing — see **[GOVERNANCE.md](./docs-fork/GOVERNANCE.md)**.

The governance document covers:
- Fork structure and branch conventions
- Upstream sync procedures (with conflict resolution)
- Feature branch workflow for adding patches
- Build and verification commands
- Push procedures and force-push safety
- Recovery scenarios and common mistakes to avoid

---

## Compatibility

This fork is **backward-compatible** with upstream headroom. The provider default change (`None → "local"`) only affects behavior when no provider is explicitly passed — existing code that passes a provider explicitly is unaffected.

---

## License

MIT — Same as upstream headroom.

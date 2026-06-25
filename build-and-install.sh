#!/usr/bin/env bash
# build-and-install.sh — Build and install better-headroom
#
# Usage:
#   ./build-and-install.sh --help
#   ./build-and-install.sh --install-editable
#   ./build-and-install.sh --build-wheel
#   ./build-and-install.sh --install-wheel
#
# Auto-installs maturin and Rust if missing.
# Uses .venv for Python environment (creates if missing).

set -euo pipefail

REPO_DIR="/Users/oleksii.honchar/www/misc/better-headroom"
VENV_DIR="$REPO_DIR/.venv"
UPSTREAM="upstream"
BRANCH="patched/main"

# Find Python 3.10+ (headroom requires >=3.10)
PYTHON_CMD="python3"
if command -v /opt/homebrew/bin/python3.12 >/dev/null 2>&1; then
  PYTHON_CMD="/opt/homebrew/bin/python3.12"
elif command -v python3.11 >/dev/null 2>&1; then
  PYTHON_CMD="python3.11"
elif command -v python3.12 >/dev/null 2>&1; then
  PYTHON_CMD="python3.12"
fi

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --install-editable    Build and install in editable mode (for development)
  --build-wheel         Build a wheel to dist/ (for distribution)
  --install-wheel       Install from the built wheel
  --sync-upstream       Fetch and rebase onto upstream/main
  --help                Show this help message

Auto-installs:
  - maturin (if missing: pip install maturin)
  - Rust (if missing: rustup install stable)

Examples:
  # Quick development install
  $(basename "$0") --install-editable

  # Build wheel for distribution
  $(basename "$0") --build-wheel

  # Sync with upstream before building
  $(basename "$0") --sync-upstream && $(basename "$0") --install-editable

EOF
}

install_rust() {
  echo "📦 Installing Rust via rustup..."
  if command -v rustc >/dev/null 2>&1; then
    echo "   ✅ Rust already installed: $(rustc --version)"
    return 0
  fi

  # Install rustup non-interactive
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  source "$HOME/.cargo/env"
  echo "   ✅ Rust installed: $(rustc --version)"
}

install_maturin() {
  echo "📦 Installing maturin..."
  if command -v maturin >/dev/null 2>&1; then
    echo "   ✅ maturin already installed: $(maturin --version)"
    return 0
  fi

  # Use the venv pip if available, otherwise system pip
  local pip_cmd="pip3"
  if [[ -x "$VENV_DIR/bin/pip" ]]; then
    pip_cmd="$VENV_DIR/bin/pip"
  fi

  "$pip_cmd" install maturin
  echo "   ✅ maturin installed: $(maturin --version 2>/dev/null || echo 'installed')"
}

ensure_venv() {
  echo "📦 Ensuring Python virtual environment..."
  local needs_create=false

  if [[ ! -d "$VENV_DIR" ]]; then
    needs_create=true
  else
    # Check if venv Python satisfies >=3.10
    local venv_python
    venv_python=$("$VENV_DIR/bin/python3" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
    if [[ "$venv_python" == "3.9" ]]; then
      echo "   ⚠️  Existing venv uses Python 3.9, recreating with $PYTHON_CMD..."
      rm -rf "$VENV_DIR"
      needs_create=true
    fi
  fi

  if [[ "$needs_create" == "true" ]]; then
    "$PYTHON_CMD" -m venv "$VENV_DIR"
    local py_version
    py_version=$("$VENV_DIR/bin/python3" --version 2>&1)
    echo "   ✅ Created venv at $VENV_DIR ($py_version)"
  else
    echo "   ✅ Venv already exists at $VENV_DIR"
  fi

  # Activate the venv for subsequent commands
  source "$VENV_DIR/bin/activate"
}

# Install better-litellm into the venv so headroom can find litellm>=1.86.2
# (PyPI only has 1.83.9; better-litellm 1.89.0 is a local fork)
install_better_litellm() {
  local BETTER_LITELLM_DIR="/Users/oleksii.honchar/www/misc/better-litellm"

  if [[ -d "$BETTER_LITELLM_DIR" ]]; then
    echo "📦 Installing better-litellm into venv (satisfies litellm>=1.86.2)..."
    source "$VENV_DIR/bin/activate"
    pip install -e "$BETTER_LITELLM_DIR" --quiet
    local version
    version=$(python -c "import litellm; print(litellm.__version__)" 2>/dev/null || echo "?")
    echo "   ✅ litellm version: $version"
  else
    echo "   ⚠️  better-litellm not found at $BETTER_LITELLM_DIR"
  fi
}

check_prereqs() {
  local missing=()

  command -v python3 >/dev/null 2>&1 || missing+=("python3")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Missing required tools:"
    for tool in "${missing[@]}"; do
      echo "   - $tool"
    done
    exit 1
  fi

  # Auto-install Rust and maturin
  install_rust
  ensure_venv
  install_maturin
}

sync_upstream() {
  echo "🔄 Syncing with upstream..."
  cd "$REPO_DIR"

  git fetch "$UPSTREAM" main --quiet

  local behind ahead
  behind=$(git log --oneline "$BRANCH".."$UPSTREAM/main" | wc -l)
  ahead=$(git log --oneline "$UPSTREAM/main".."$(git rev-parse "$BRANCH")" | wc -l)

  echo "   Behind upstream: $behind commits"
  echo "   Ahead upstream:  $ahead commits"

  if [[ "$behind" -gt 0 ]]; then
    git checkout "$BRANCH"
    git rebase "$UPSTREAM/main"
    echo "   ✅ Rebased onto upstream/main"
  else
    echo "   ✅ Already up to date with upstream"
  fi
}

build_wheel() {
  echo "🔨 Building wheel..."
  cd "$REPO_DIR"
  source "$VENV_DIR/bin/activate"

  maturin build --release

  echo ""
  echo "✅ Wheel built in dist/"
  ls -lh dist/*.whl
}

install_editable() {
  echo "📦 Installing in editable mode..."
  cd "$REPO_DIR"
  source "$VENV_DIR/bin/activate"

  maturin develop --release

  echo ""
  echo "✅ Installed in editable mode"
  python -c "import headroom; print(f'headroom version: {headroom.__version__}')"
}

install_wheel() {
  echo "📦 Installing from wheel..."
  cd "$REPO_DIR"
  source "$VENV_DIR/bin/activate"

  local wheel
  wheel=$(ls dist/*.whl 2>/dev/null | head -1)

  if [[ -z "$wheel" ]]; then
    echo "❌ No wheel found in dist/. Run --build-wheel first."
    exit 1
  fi

  pip install --force-reinstall "$wheel"

  echo ""
  echo "✅ Installed from wheel"
  python -c "import headroom; print(f'headroom version: {headroom.__version__}')"
}

# Main
if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

ACTION=""
SYNC=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help)
      usage
      exit 0
      ;;
    --install-editable)
      ACTION="install-editable"
      ;;
    --build-wheel)
      ACTION="build-wheel"
      ;;
    --install-wheel)
      ACTION="install-wheel"
      ;;
    --sync-upstream)
      SYNC=true
      ;;
    *)
      echo "❌ Unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ -z "$ACTION" && "$SYNC" == "false" ]]; then
  echo "❌ No action specified. Use --help for usage."
  exit 1
fi

check_prereqs

if [[ "$SYNC" == "true" ]]; then
  sync_upstream
fi

case "$ACTION" in
  install-editable)
    install_editable
    ;;
  build-wheel)
    build_wheel
    ;;
  install-wheel)
    install_wheel
    ;;
esac

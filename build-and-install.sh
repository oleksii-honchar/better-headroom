#!/usr/bin/env bash
# build-and-install.sh — Build and install better-headroom
#
# Usage:
#   ./scripts/build-and-install.sh --help
#   ./scripts/build-and-install.sh --install-editable
#   ./scripts/build-and-install.sh --build-wheel
#   ./scripts/build-and-install.sh --install-wheel
#
# Requires:
#   - maturin (pip install maturin)
#   - Rust (rustup install stable)
#   - Python 3.11+

set -euo pipefail

REPO_DIR="/Users/oleksii.honchar/www/misc/better-headroom"
UPSTREAM="upstream"
BRANCH="patched/main"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Options:
  --install-editable    Build and install in editable mode (for development)
  --build-wheel         Build a wheel to dist/ (for distribution)
  --install-wheel       Install from the built wheel
  --sync-upstream       Fetch and rebase onto upstream/main
  --help                Show this help message

Examples:
  # Quick development install
  $(basename "$0") --install-editable

  # Build wheel for distribution
  $(basename "$0") --build-wheel

  # Sync with upstream before building
  $(basename "$0") --sync-upstream && $(basename "$0") --install-editable

Requires:
  - maturin (pip install maturin)
  - Rust (rustup install stable)
  - Python 3.11+

EOF
}

check_prereqs() {
  local missing=()

  command -v maturin >/dev/null 2>&1 || missing+=("maturin")
  command -v python3 >/dev/null 2>&1 || missing+=("python3")
  command -v rustc >/dev/null 2>&1 || missing+=("rustc (Rust toolchain)")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ Missing required tools:"
    for tool in "${missing[@]}"; do
      echo "   - $tool"
    done
    echo ""
    echo "Install:"
    echo "  - maturin: pip install maturin"
    echo "  - Rust:    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
  fi
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

  maturin build --release

  echo ""
  echo "✅ Wheel built in dist/"
  ls -lh dist/*.whl
}

install_editable() {
  echo "📦 Installing in editable mode..."
  cd "$REPO_DIR"

  maturin develop --release

  echo ""
  echo "✅ Installed in editable mode"
  python3 -c "import headroom; print(f'headroom version: {headroom.__version__}')"
}

install_wheel() {
  echo "📦 Installing from wheel..."
  cd "$REPO_DIR"

  local wheel
  wheel=$(ls dist/*.whl 2>/dev/null | head -1)

  if [[ -z "$wheel" ]]; then
    echo "❌ No wheel found in dist/. Run --build-wheel first."
    exit 1
  fi

  pip install --force-reinstall "$wheel"

  echo ""
  echo "✅ Installed from wheel"
  python3 -c "import headroom; print(f'headroom version: {headroom.__version__}')"
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

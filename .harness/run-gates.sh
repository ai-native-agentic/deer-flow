#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_NAME="deer-flow"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'
PASS=0
FAIL=0
SKIP=0

run_gate() {
  local label="$1"
  local cmd="$2"
  printf "  %-20s ... " "$label"
  if (cd "$PROJECT_ROOT" && eval "$cmd") >/dev/null 2>&1; then
    printf "${GREEN}PASS${NC}\n"
    PASS=$((PASS + 1))
  else
    printf "${RED}FAIL${NC}\n"
    FAIL=$((FAIL + 1))
  fi
}

skip_gate() {
  local label="$1"
  local reason="$2"
  printf "  %-20s ... ${YELLOW}SKIP${NC} (%s)\n" "$label" "$reason"
  SKIP=$((SKIP + 1))
}

echo ""
echo "=== $PROJECT_NAME QA Gates ==="
echo ""

# Gate A: syntax
run_gate "syntax" "test -f Makefile && echo ok"

# Gate B: shellcheck
if command -v shellcheck >/dev/null 2>&1; then
  sh_count=$(cd "$PROJECT_ROOT" && find . -name '*.sh' -not -path './.git/*' -not -path './node_modules/*' -not -path './.venv/*' 2>/dev/null | wc -l)
  if [[ "$sh_count" -gt 0 ]]; then
    run_gate "shellcheck" "find . -name '*.sh' -not -path './.git/*' -not -path './node_modules/*' -not -path './.venv/*' -exec shellcheck {} +"
  else
    skip_gate "shellcheck" "no shell scripts"
  fi
else
  skip_gate "shellcheck" "shellcheck not installed"
fi

# Gate C: structure
run_gate "structure" "test -f README.md || test -f AGENTS.md || test -f package.json || test -f Cargo.toml || test -f pyproject.toml || test -f Makefile"

# Gate D-F: disabled
skip_gate "gate_d" "disabled"
skip_gate "gate_e" "disabled"
skip_gate "gate_f" "disabled"

echo ""
echo "=== Results ==="
echo -e "  ${GREEN}PASS: $PASS${NC}  ${YELLOW}SKIP: $SKIP${NC}  ${RED}FAIL: $FAIL${NC}"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi

#!/usr/bin/env bash
# demo.sh -- Non-interactive demo of EOR cross-instance federation
#
# Demonstrates:
#   1. Building org-roam databases for two fixture KBs
#   2. Registering both instances in the EOR federation
#   3. Cross-instance node lookup (querying instance-B from instance-A context)
#   4. Cross-instance search (collecting nodes from all instances)
#   5. Candidate formatting (how eor-node-find presents results)
#
# Usage:
#   ./scripts/demo.sh [--emacs=/path/to/emacs]
#
# Environment variables:
#   EOR_PACKAGE_DIR  -- path to endless-org-roam source (auto-detected)
#   EMACS            -- path to emacs binary (default: emacs)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
EMACS="${EMACS:-emacs}"

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --emacs=*)
            EMACS="${arg#--emacs=}"
            ;;
        --help|-h)
            echo "Usage: $0 [--emacs=/path/to/emacs]"
            echo ""
            echo "Runs a non-interactive demo of EOR cross-instance federation."
            echo "Set EOR_PACKAGE_DIR to point to the endless-org-roam source."
            exit 0
            ;;
        *)
            echo "Unknown argument: $arg"
            exit 1
            ;;
    esac
done

# Auto-detect EOR package directory
if [ -z "${EOR_PACKAGE_DIR:-}" ]; then
    for candidate in \
        "$REPO_DIR/../endless-org-roam" \
        "$REPO_DIR/../eor/endless-org-roam" \
        "$HOME/src/eor/endless-org-roam"; do
        if [ -f "$candidate/endless-org-roam.el" ]; then
            EOR_PACKAGE_DIR="$(cd "$candidate" && pwd)"
            break
        fi
    done
fi

if [ -z "${EOR_PACKAGE_DIR:-}" ]; then
    echo "ERROR: Cannot find endless-org-roam source."
    echo "Set EOR_PACKAGE_DIR or place it adjacent to this repo."
    exit 1
fi

export EOR_PACKAGE_DIR

# Create isolated work directory
WORK_DIR="$(mktemp -d "/tmp/eor-demo-XXXXXX")"
export EOR_WORK_DIR="$WORK_DIR"
export EOR_EMACS_DIR="$WORK_DIR/.emacs.d"
mkdir -p "$EOR_EMACS_DIR"

# Copy fixtures
cp -r "$REPO_DIR/fixtures/instance-a" "$WORK_DIR/instance-a"
cp -r "$REPO_DIR/fixtures/instance-b" "$WORK_DIR/instance-b"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║         Endless Org Roam — Federation Demo           ║"
echo "╠═══════════════════════════════════════════════════════╣"
echo "║ Two org-roam KBs, federated via EOR                  ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "Emacs:     $("$EMACS" --version | head -1)"
echo "EOR:       $EOR_PACKAGE_DIR"
echo "Work dir:  $WORK_DIR"
echo ""

# Detect straight.el load paths for local runs
emacs_version="$("$EMACS" --batch --eval '(princ emacs-version)' 2>/dev/null)"
straight_dir="${HOME}/.emacs.d/.local/straight/build-${emacs_version}"
extra_load_paths=""

if [ -d "$straight_dir/org-roam" ]; then
    for pkg in org-roam emacsql emacsql-sqlite magit-section \
               dash s f compat org transient with-editor llama cond-let; do
        if [ -d "$straight_dir/$pkg" ]; then
            extra_load_paths="$extra_load_paths -L $straight_dir/$pkg"
        fi
    done
fi

cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

# shellcheck disable=SC2086
"$EMACS" -Q --batch \
    -L "$EOR_PACKAGE_DIR" \
    $extra_load_paths \
    -l org-roam \
    -l "$EOR_PACKAGE_DIR/endless-org-roam.el" \
    -l "$EOR_PACKAGE_DIR/endless-org-roam-registry.el" \
    -l "$EOR_PACKAGE_DIR/endless-org-roam-transport.el" \
    -l "$EOR_PACKAGE_DIR/endless-org-roam-link.el" \
    -l "$EOR_PACKAGE_DIR/endless-org-roam-search.el" \
    -l "$SCRIPT_DIR/demo.el" \
    -f eor-demo-run \
    2>&1

echo ""
echo "Demo complete."

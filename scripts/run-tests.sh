#!/usr/bin/env bash
# run-tests.sh -- Main E2E test runner for endless-org-roam
#
# Usage:
#   ./scripts/run-tests.sh --profile=vanilla [--emacs=/path/to/emacs]
#   ./scripts/run-tests.sh --profile=doom
#   ./scripts/run-tests.sh --profile=spacemacs
#   ./scripts/run-tests.sh --all  (runs all profiles)
#
# Environment variables:
#   EOR_PACKAGE_DIR  -- path to endless-org-roam source (auto-detected)
#   EMACS            -- path to emacs binary (default: emacs)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
EMACS="${EMACS:-emacs}"
PROFILE=""
RUN_ALL=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --profile=*)
            PROFILE="${arg#--profile=}"
            ;;
        --emacs=*)
            EMACS="${arg#--emacs=}"
            ;;
        --all)
            RUN_ALL=true
            ;;
        --help|-h)
            echo "Usage: $0 --profile=<vanilla|doom|spacemacs> [--emacs=/path/to/emacs]"
            echo "       $0 --all"
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
    # Try common locations relative to this repo
    for candidate in \
        "$REPO_DIR/../eor/endless-org-roam" \
        "$REPO_DIR/../endless-org-roam" \
        "$HOME/src/eor/endless-org-roam"; do
        if [ -f "$candidate/endless-org-roam.el" ]; then
            EOR_PACKAGE_DIR="$(cd "$candidate" && pwd)"
            break
        fi
    done
fi

if [ -z "${EOR_PACKAGE_DIR:-}" ]; then
    echo "ERROR: Cannot find endless-org-roam source."
    echo "Set EOR_PACKAGE_DIR or place it at ../eor/endless-org-roam"
    exit 1
fi

export EOR_PACKAGE_DIR
echo "=== EOR Test Runner ==="
echo "Emacs:   $("$EMACS" --version | head -1)"
echo "EOR:     $EOR_PACKAGE_DIR"
echo "Repo:    $REPO_DIR"
echo ""

run_profile() {
    local profile="$1"
    local profile_dir="$REPO_DIR/profiles/$profile"

    if [ ! -d "$profile_dir" ]; then
        echo "ERROR: Profile not found: $profile_dir"
        return 1
    fi

    echo "--- Running E2E tests with profile: $profile ---"

    # Create a fresh temp directory for this test run
    local work_dir
    work_dir="$(mktemp -d "/tmp/eor-e2e-${profile}-XXXXXX")"
    export EOR_WORK_DIR="$work_dir"
    export EOR_EMACS_DIR="$work_dir/.emacs.d"
    mkdir -p "$EOR_EMACS_DIR"

    # Copy fixtures into work dir so tests can mutate them
    cp -r "$REPO_DIR/fixtures/instance-a" "$work_dir/instance-a"
    cp -r "$REPO_DIR/fixtures/instance-b" "$work_dir/instance-b"

    local exit_code=0

    # Detect straight.el load paths for local testing (Doom Emacs)
    local emacs_version
    emacs_version="$("$EMACS" --batch --eval '(princ emacs-version)' 2>/dev/null)"
    local straight_dir="${HOME}/.emacs.d/.local/straight/build-${emacs_version}"
    local extra_load_paths=""

    if [ -d "$straight_dir/org-roam" ]; then
        # Use local straight.el packages (fast, no network)
        for pkg in org-roam emacsql emacsql-sqlite magit-section \
                   dash s f compat org transient with-editor llama cond-let; do
            if [ -d "$straight_dir/$pkg" ]; then
                extra_load_paths="$extra_load_paths -L $straight_dir/$pkg"
            fi
        done
    fi

    case "$profile" in
        vanilla)
            # shellcheck disable=SC2086
            "$EMACS" -Q --batch \
                -L "$EOR_PACKAGE_DIR" \
                $extra_load_paths \
                -l org-roam \
                -l "$EOR_PACKAGE_DIR/endless-org-roam.el" \
                -l "$EOR_PACKAGE_DIR/endless-org-roam-registry.el" \
                -l "$EOR_PACKAGE_DIR/endless-org-roam-transport.el" \
                -l "$EOR_PACKAGE_DIR/endless-org-roam-link.el" \
                -l "$REPO_DIR/tests/test-e2e-common.el" \
                -f eor-e2e-run-all \
                || exit_code=$?
            ;;
        doom)
            if [ -x "${HOME}/.config/emacs/bin/doom" ]; then
                "${HOME}/.config/emacs/bin/doom" run --batch \
                    -L "$EOR_PACKAGE_DIR" \
                    -l "$REPO_DIR/tests/test-e2e-common.el" \
                    -f eor-e2e-run-all \
                    || exit_code=$?
            else
                echo "SKIP: Doom not installed locally (use CI matrix)"
            fi
            ;;
        spacemacs)
            if [ -f "${HOME}/.emacs.d/spacemacs.mk" ]; then
                "$EMACS" --batch \
                    -l "${HOME}/.emacs.d/init.el" \
                    -L "$EOR_PACKAGE_DIR" \
                    -l "$REPO_DIR/tests/test-e2e-common.el" \
                    -f eor-e2e-run-all \
                    || exit_code=$?
            else
                echo "SKIP: Spacemacs not installed locally (use CI matrix)"
            fi
            ;;
    esac

    # Cleanup
    rm -rf "$work_dir"

    if [ "$exit_code" -ne 0 ]; then
        echo "FAIL: $profile profile tests failed (exit $exit_code)"
    else
        echo "PASS: $profile profile"
    fi
    echo ""

    return "$exit_code"
}

if [ "$RUN_ALL" = true ]; then
    failures=0
    for p in vanilla doom spacemacs; do
        run_profile "$p" || ((failures++))
    done
    if [ "$failures" -gt 0 ]; then
        echo "=== $failures profile(s) failed ==="
        exit 1
    fi
    echo "=== All profiles passed ==="
elif [ -n "$PROFILE" ]; then
    run_profile "$PROFILE"
else
    echo "ERROR: Specify --profile=<name> or --all"
    exit 1
fi

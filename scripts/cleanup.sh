#!/usr/bin/env bash
# cleanup.sh -- Clean up temporary test artifacts
#
# Usage:
#   ./scripts/cleanup.sh

set -euo pipefail

echo "Cleaning up EOR test artifacts..."

# Remove temp directories created by test runs
rm -rf /tmp/eor-e2e-*
rm -rf /tmp/eor-test-*

echo "Done."

#!/usr/bin/env bash
# setup-profile.sh -- Install packages for a given Emacs profile
#
# Usage:
#   ./scripts/setup-profile.sh vanilla
#   ./scripts/setup-profile.sh doom
#   ./scripts/setup-profile.sh spacemacs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PROFILE="${1:-}"
EMACS="${EMACS:-emacs}"

if [ -z "$PROFILE" ]; then
    echo "Usage: $0 <vanilla|doom|spacemacs>"
    exit 1
fi

echo "=== Setting up profile: $PROFILE ==="

case "$PROFILE" in
    vanilla)
        echo "Vanilla profile uses straight.el -- packages install on first load."
        echo "No pre-setup needed for batch mode testing."
        ;;
    doom)
        echo "Doom profile setup:"
        echo "  1. Clone Doom Emacs: git clone --depth 1 https://github.com/doomemacs/doomemacs ~/.config/emacs"
        echo "  2. Copy profiles/doom/ files into ~/.config/doom/"
        echo "  3. Run: doom sync"
        echo ""
        echo "For CI, this is automated in the GitHub Actions workflow."
        ;;
    spacemacs)
        echo "Spacemacs profile setup:"
        echo "  1. Clone Spacemacs: git clone https://github.com/syl20bnr/spacemacs ~/.emacs.d"
        echo "  2. Copy profiles/spacemacs/.spacemacs to ~/.spacemacs"
        echo "  3. Run: emacs --batch -l ~/.emacs.d/init.el"
        echo ""
        echo "For CI, this is automated in the GitHub Actions workflow."
        ;;
    *)
        echo "Unknown profile: $PROFILE"
        exit 1
        ;;
esac

#!/usr/bin/env bash
# Publishes Ledgerproof (full history and tags) to github.com/TayyibI/ledgerproof.
# Usage: put this file and ledgerproof.bundle in the same folder, then run:  bash push_ledgerproof.sh
set -euo pipefail
cd "$(dirname "$0")"
[ -f ledgerproof.bundle ] || { echo "ledgerproof.bundle not found next to this script"; exit 1; }
command -v git >/dev/null || { echo "git is not installed: https://git-scm.com/downloads"; exit 1; }
rm -rf ledgerproof-push
git clone ledgerproof.bundle ledgerproof-push
cd ledgerproof-push
git branch -M main
git remote set-url origin https://github.com/TayyibI/ledgerproof.git
echo "Pushing. A browser or password prompt from GitHub may appear: sign in as TayyibI."
git push -u origin main --tags --force
echo "Done: https://github.com/TayyibI/ledgerproof"

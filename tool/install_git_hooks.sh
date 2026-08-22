#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

chmod +x .githooks/pre-push
git config --local core.hooksPath .githooks

printf 'Git hooks installed: core.hooksPath=.githooks\n'
printf 'git push will now run make pre-push automatically.\n'

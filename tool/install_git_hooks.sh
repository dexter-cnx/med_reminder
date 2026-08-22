#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

chmod +x .githooks/pre-commit .githooks/pre-push
git config --local core.hooksPath .githooks

printf 'Git hooks installed: core.hooksPath=.githooks\n'
printf 'git commit will now run make format and re-stage formatted Dart files.\n'
printf 'git push will run CI-equivalent pre-push validation automatically.\n'

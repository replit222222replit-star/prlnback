#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="/workspaces/repo"
BRANCH="main"
REMOTE_URL="https://github.com/anva4/iuser.git"

cd "$REPO_DIR"

echo "Initializing repository metadata..."
git status >/dev/null 2>&1 || git init

git remote remove origin >/dev/null 2>&1 || true
git remote add origin "$REMOTE_URL"

git add .

git commit -m "Initialize NEO-GENESIS Flutter + Firebase project" || true

git branch -M "$BRANCH"
git push -u origin "$BRANCH" --force

echo "Deployment script finished. Repository pushed to $REMOTE_URL"

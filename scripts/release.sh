#!/usr/bin/env bash
# release.sh [patch|minor|major]   (default: patch)
#
# Releases this repo's Claude plugin (versioned via .claude-plugin/plugin.json).
#
# Prints a plan (version bump, every path that will be staged, the commit
# message, the GitHub release), asks for a plain y/N confirmation, then
# bumps -> commits (all changes in the working tree, via git add -A) ->
# pushes -> creates an idempotent GitHub release.
#
# Must be run from a clean main branch with no unpushed commits.
set -euo pipefail

BUMP="${1:-patch}"

require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "ERROR: '$1' is required but not installed" >&2
    exit 1
  fi
}

version_file() {
  echo "$(git rev-parse --show-toplevel)/.claude-plugin/plugin.json"
}

current_version() {
  local file
  file="$(version_file)"
  if [[ ! -f "$file" ]]; then
    echo "ERROR: version file not found at $file" >&2
    exit 1
  fi
  jq -r '.version' "$file"
}

# compute_new_version <current-semver> <patch|minor|major> -> new semver
compute_new_version() {
  local current="$1" bump="$2"
  if [[ ! "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
    echo "ERROR: version '$current' is not valid semver (X.Y.Z)" >&2
    exit 1
  fi
  local major="${BASH_REMATCH[1]}" minor="${BASH_REMATCH[2]}" patch="${BASH_REMATCH[3]}"
  case "$bump" in
    patch) patch=$((patch + 1)) ;;
    minor)
      minor=$((minor + 1))
      patch=0
      ;;
    major)
      major=$((major + 1))
      minor=0
      patch=0
      ;;
  esac
  echo "${major}.${minor}.${patch}"
}

write_version() {
  local newver="$1" file tmp
  file="$(version_file)"
  tmp="$(mktemp)"
  jq --arg v "$newver" '.version = $v' "$file" >"$tmp"
  mv "$tmp" "$file"
}

case "$BUMP" in
  patch | minor | major) ;;
  *)
    echo "ERROR: unknown bump type '$BUMP'. Use patch, minor, or major." >&2
    exit 1
    ;;
esac

require_cmd git
require_cmd jq
require_cmd gh

cd "$(git rev-parse --show-toplevel)"

branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$branch" != "main" ]]; then
  echo "ERROR: must be on main branch (currently on '$branch')" >&2
  exit 1
fi

# On main, no working-tree changes but local commits ahead of origin/main
# almost always means a previous release committed but failed to push.
# Re-running would bump the version a second time, so stop with instructions.
if [[ -z "$(git status --porcelain)" ]] && [[ -n "$(git log origin/main..HEAD --oneline)" ]]; then
  echo "ERROR: local commit(s) on main are not yet pushed to origin/main." >&2
  echo "A previous release likely committed but failed to push. Finish it manually:" >&2
  echo "  git push origin main" >&2
  echo "Then create the GitHub release if it's still missing." >&2
  echo "Do NOT re-run this script — it would bump the version again." >&2
  exit 1
fi

if [[ -z "$(git status --porcelain)" ]]; then
  echo "ERROR: no changes compared to origin/main. Nothing to release." >&2
  exit 1
fi

CUR="$(current_version)"
NEW="$(compute_new_version "$CUR" "$BUMP")"

echo "=== RELEASE PLAN (bump: $BUMP) ==="
echo
echo "Version bump:"
printf '  %-10s %s -> %s\n' "ty" "$CUR" "$NEW"
echo
echo "Will stage ALL changes in the repository (git add -A):"
git status --porcelain | sed 's/^/  /'
echo
echo "Commit (directly to main):"
echo "  chore: release ty:${NEW}"
echo
echo "GitHub release:"
echo "  tag v${NEW}   title ty:${NEW}"
echo

read -rp "Proceed with bump, commit to main, push, and release? [y/N] " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Cancelled. Nothing changed."
  exit 0
fi

write_version "$NEW"

git add -A
git commit -m "chore: release ty:${NEW}"
git push origin main

REPO="$(git remote get-url origin | sed -E 's|\.git$||; s|.*[:/]([^/]+/[^/]+)$|\1|')"
TAG="v${NEW}"
URL="https://github.com/${REPO}/releases/tag/${TAG}"

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  echo "$URL  (already existed, skipped)"
elif gh release create "$TAG" --repo "$REPO" --title "ty:${NEW}" --notes "Bump ty to v${NEW}."; then
  echo "$URL"
else
  echo
  echo "ERROR: commit + push succeeded, but the GitHub release failed to create:" >&2
  echo "  gh release create ${TAG} --repo ${REPO} --title \"ty:${NEW}\" --notes \"Bump ty to v${NEW}.\"" >&2
  echo "Run the command above to finish. Do NOT re-run this script — it would bump the version again." >&2
  exit 1
fi

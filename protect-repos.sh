#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./protect-repos.sh [--dry-run] <github-user-or-org>

Examples:
  ./protect-repos.sh my-org
  ./protect-repos.sh --dry-run my-org

Requirements:
  - gh CLI installed and authenticated
  - Permission to administer the target repositories
EOF
}

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      break
      ;;
  esac
done

OWNER="${1:-}"
if [[ -z "$OWNER" ]]; then
  usage >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI is not installed." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

RULESET_NAME="Block force pushes on all branches"
API_VERSION="2026-03-10"

build_payload() {
  cat <<EOF
{
  "name": "$RULESET_NAME",
  "target": "branch",
  "enforcement": "active",
  "bypass_actors": [],
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/*"],
      "exclude": []
    }
  },
  "rules": [
    { "type": "non_fast_forward" },
    { "type": "deletion" }
  ]
}
EOF
}

create_ruleset() {
  local repo_owner="$1"
  local repo="$2"
  local payload
  local created_id

  payload="$(build_payload)"

  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "  DRY RUN: would create ruleset with payload:"
    printf '%s\n' "$payload" | sed 's/^/    /'
    return 0
  fi

  created_id="$(
    gh api -X POST "repos/$repo_owner/$repo/rulesets" \
      -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" \
      -H "X-GitHub-Api-Version: $API_VERSION" \
      --jq '.id' \
      --input - <<<"$payload"
  )" || {
    echo "  ERROR: failed to create ruleset for $repo_owner/$repo" >&2
    return 1
  }

  if [[ -n "$created_id" ]]; then
    echo "  OK: ruleset created: $created_id"
  else
    echo "  OK: ruleset created"
  fi
}

while IFS= read -r full; do
  [[ -z "$full" ]] && continue

  repo_owner="${full%%/*}"
  repo="${full#*/}"

  echo "Repo: $full"

  existing_id="$(
    gh api "repos/$repo_owner/$repo/rulesets" \
      --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" 2>/dev/null || true
  )"

  if [[ -n "$existing_id" ]]; then
    echo "  OK: ruleset already exists: $existing_id"
    continue
  fi

  create_ruleset "$repo_owner" "$repo"
done < <(
  gh repo list "$OWNER" \
    --limit 1000 \
    --no-archived \
    --json nameWithOwner,viewerCanAdminister,isArchived \
    --jq '.[] | select(.viewerCanAdminister == true and .isArchived == false) | .nameWithOwner'
)

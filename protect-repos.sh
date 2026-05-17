#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./protect-repos.sh [--dry-run] [--audit] [--format table|csv] <github-user-or-org>

Examples:
  ./protect-repos.sh my-org
  ./protect-repos.sh --dry-run my-org
  ./protect-repos.sh --audit my-org
  ./protect-repos.sh --audit --format csv my-org

Requirements:
  - gh CLI installed and authenticated
  - Permission to administer the target repositories
EOF
}

DRY_RUN=0
MODE="enforce"
OUTPUT_FORMAT="table"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --audit)
      MODE="audit"
      shift
      ;;
    --format)
      OUTPUT_FORMAT="${2:-}"
      if [[ -z "$OUTPUT_FORMAT" ]]; then
        echo "Error: --format requires a value." >&2
        exit 1
      fi
      shift 2
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

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is not installed." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh CLI is not authenticated. Run: gh auth login" >&2
  exit 1
fi

if [[ "$OUTPUT_FORMAT" != "table" && "$OUTPUT_FORMAT" != "csv" ]]; then
  echo "Error: --format must be 'table' or 'csv'." >&2
  exit 1
fi

RULESET_NAME="Block force pushes on all branches"
API_VERSION="2026-03-10"

build_payload() {
  jq -n --arg name "$RULESET_NAME" '{
    name: $name,
    target: "branch",
    enforcement: "active",
    bypass_actors: [],
    conditions: {
      ref_name: {
        include: ["refs/heads/*"],
        exclude: []
      }
    },
    rules: [
      { type: "non_fast_forward" },
      { type: "deletion" }
    ]
  }'
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
    printf '%s' "$payload" | gh api -X POST "repos/$repo_owner/$repo/rulesets" \
      -H "Accept: application/vnd.github+json" \
      -H "Content-Type: application/json" \
      -H "X-GitHub-Api-Version: $API_VERSION" \
      --input - \
      --jq '.id'
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

get_ruleset_status() {
  local full="$1"
  local local_existing_id=""
  local stderr_file
  local repo_owner
  local repo
  local gh_output
  local gh_status=0

  [[ -z "$full" ]] && return 0

  repo_owner="${full%%/*}"
  repo="${full#*/}"

  stderr_file="$(mktemp)"

  gh_output="$(
    gh api --paginate "repos/$repo_owner/$repo/rulesets" \
      -H "Accept: application/vnd.github+json" \
      -H "X-GitHub-Api-Version: $API_VERSION" \
      --jq ".[] | select(.name == \"$RULESET_NAME\") | .id" \
      2>"$stderr_file"
  )" || gh_status=$?

  if (( gh_status != 0 )); then
    if grep -q "Upgrade to GitHub Pro or make this repository public" "$stderr_file"; then
      rm -f "$stderr_file"
      printf 'blocked_by_plan\t-\n'
      return 0
    fi

    cat "$stderr_file" >&2
    rm -f "$stderr_file"
    printf 'error\t-\n'
    return 1
  fi

  rm -f "$stderr_file"
  local_existing_id="$gh_output"

  if [[ -n "$local_existing_id" ]]; then
    printf 'protected\t%s\n' "$local_existing_id"
    return 0
  fi

  printf 'missing\t-\n'
}

print_audit_row() {
  local repo="$1"
  local status="$2"
  local detail="$3"

  if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
    printf '"%s","%s","%s"\n' "$repo" "$status" "$detail"
  else
    printf '%-55s %-18s %s\n' "$repo" "$status" "$detail"
  fi
}

process_repo() {
  local full="$1"
  local status_detail
  local status
  local detail
  local repo_owner
  local repo

  [[ -z "$full" ]] && return 0

  repo_owner="${full%%/*}"
  repo="${full#*/}"

  echo "Repo: $full"

  status_detail="$(get_ruleset_status "$full")" || {
    echo "  ERROR: failed to list rulesets for $full" >&2
    return 1
  }

  status="${status_detail%%$'\t'*}"
  detail="${status_detail#*$'\t'}"

  if [[ "$status" == "protected" ]]; then
    echo "  OK: ruleset already exists: $detail"
    return 0
  fi

  if [[ "$status" == "blocked_by_plan" ]]; then
    echo "  ERROR: rulesets unavailable for this repository plan" >&2
    return 1
  fi

  if ! create_ruleset "$repo_owner" "$repo"; then
    return 1
  fi
}

audit_repo() {
  local full="$1"
  local status_detail
  local status
  local detail

  [[ -z "$full" ]] && return 0

  status_detail="$(get_ruleset_status "$full")" || true
  status="${status_detail%%$'\t'*}"
  detail="${status_detail#*$'\t'}"

  print_audit_row "$full" "$status" "$detail"

  if [[ "$status" == "error" ]]; then
    return 1
  fi
}

list_repos() {
  gh repo list "$OWNER" \
    --limit 1000 \
    --no-archived \
    --json nameWithOwner,viewerCanAdminister \
    --jq '.[] | select(.viewerCanAdminister == true) | .nameWithOwner'
}

failures=0

if [[ "$MODE" == "audit" ]]; then
  if [[ "$OUTPUT_FORMAT" == "csv" ]]; then
    printf '"repo","status","detail"\n'
  else
    printf '%-55s %-18s %s\n' "REPOSITORY" "STATUS" "DETAIL"
  fi
fi

while IFS= read -r full; do
  [[ -z "$full" ]] && continue

  if [[ "$MODE" == "audit" ]]; then
    if ! audit_repo "$full"; then
      failures=$((failures + 1))
    fi
  else
    if ! process_repo "$full"; then
      failures=$((failures + 1))
    fi
  fi
done < <(list_repos)

if (( failures > 0 )); then
  echo "Completed with $failures failure(s)." >&2
  exit 1
fi

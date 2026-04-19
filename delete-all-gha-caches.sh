#!/usr/bin/env bash
# Delete all GitHub Actions caches for a repository.

set -euo pipefail

OWNER="${OWNER:-}"
REPO="${REPO:-}"
TOKEN="${TOKEN:-}"
PER_PAGE="${PER_PAGE:-100}"

usage() {
  cat <<'EOF'
Usage:
  OWNER=<owner> REPO=<repo> TOKEN=<token> [PER_PAGE=100] ./delete-all-gha-caches.sh
  ./delete-all-gha-caches.sh --owner <owner> --repo <repo> --token <token> [--per-page <n>]

Options:
  -o, --owner       Repository owner
  -r, --repo        Repository name
  -t, --token       GitHub token
  -p, --per-page    Items per page when listing caches (default: 100)
  -h, --help        Show this help
EOF
  exit "${1:-1}"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Error: required command not found: $1" >&2
    exit 1
  }
}

require_value() {
  local name="$1"
  local value="$2"

  if [[ -z "$value" ]]; then
    echo "Error: ${name} is required." >&2
    usage 1
  fi
}

require_arg_value() {
  local flag="$1"

  if [[ $# -lt 2 || -z "${2:-}" ]]; then
    echo "Error: ${flag} requires a value." >&2
    usage 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -o|--owner)
        require_arg_value "$@"
        OWNER="$2"
        shift 2
        ;;
      -r|--repo)
        require_arg_value "$@"
        REPO="$2"
        shift 2
        ;;
      -t|--token)
        require_arg_value "$@"
        TOKEN="$2"
        shift 2
        ;;
      -p|--per-page)
        require_arg_value "$@"
        PER_PAGE="$2"
        shift 2
        ;;
      -h|--help)
        usage 0
        ;;
      *)
        echo "Error: unknown argument: $1" >&2
        usage 1
        ;;
    esac
  done
}

require_command curl
require_command jq
parse_args "$@"

require_value OWNER "$OWNER"
require_value REPO "$REPO"
require_value TOKEN "$TOKEN"

API_BASE="https://api.github.com/repos/${OWNER}/${REPO}/actions"
CURL_ARGS=(
  --silent
  --show-error
  --location
  -H "Accept: application/vnd.github+json"
  -H "Authorization: Bearer ${TOKEN}"
  -H "X-GitHub-Api-Version: 2022-11-28"
)

page=1
deleted=0
errors=0

echo "Fetching caches for ${OWNER}/${REPO}..."

while true; do
  response=$(curl "${CURL_ARGS[@]}" \
    "${API_BASE}/caches?per_page=${PER_PAGE}&page=${page}")

  mapfile -t cache_ids < <(jq -r '.actions_caches[]?.id' <<<"$response")
  count=${#cache_ids[@]}

  if (( count == 0 )); then
    break
  fi

  for cache_id in "${cache_ids[@]}"; do
    echo -n "  Deleting cache ID ${cache_id}... "
    http_status=$(curl "${CURL_ARGS[@]}" \
      --output /dev/null \
      --write-out "%{http_code}" \
      -X DELETE \
      "${API_BASE}/caches/${cache_id}")

    if [[ "$http_status" == "204" ]]; then
      echo "deleted."
      ((deleted += 1))
    else
      echo "failed (HTTP ${http_status})."
      ((errors += 1))
    fi
  done

  ((page += 1))
done

echo "Done. Deleted: ${deleted}, Errors: ${errors}."

#!/usr/bin/env bash
# Trigger a GitHub Actions workflow dispatch for a repository.

set -euo pipefail

OWNER="${OWNER:-}"
REPO="${REPO:-}"
TOKEN="${TOKEN:-}"
WORKFLOW="${WORKFLOW:-}"
REF="${REF:-main}"

usage() {
  cat <<'EOF'
Usage:
  OWNER=<owner> REPO=<repo> TOKEN=<token> WORKFLOW=<workflow> [REF=main] ./trigger-workflow.sh
  ./trigger-workflow.sh --owner <owner> --repo <repo> --token <token> --workflow <workflow> [--ref <ref>]

Options:
  -o, --owner       Repository owner
  -r, --repo        Repository name
  -t, --token       GitHub token
  -w, --workflow    Workflow file name or workflow ID
      --ref         Git ref to dispatch (default: main)
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
      -w|--workflow)
        require_arg_value "$@"
        WORKFLOW="$2"
        shift 2
        ;;
      --ref)
        require_arg_value "$@"
        REF="$2"
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
require_value WORKFLOW "$WORKFLOW"

API_BASE="https://api.github.com/repos/${OWNER}/${REPO}/actions"
DISPATCH_URL="${API_BASE}/workflows/${WORKFLOW}/dispatches"
CURL_ARGS=(
  --silent
  --show-error
  --location
  -H "Accept: application/vnd.github+json"
  -H "Authorization: Bearer ${TOKEN}"
  -H "X-GitHub-Api-Version: 2022-11-28"
  -H "Content-Type: application/json"
)
REQUEST_BODY=$(jq -nc --arg ref "$REF" '{ref: $ref}')

echo "Triggering workflow ${WORKFLOW} for ${OWNER}/${REPO} on ref ${REF}..."

http_status=$(curl "${CURL_ARGS[@]}" \
  --output /dev/null \
  --write-out "%{http_code}" \
  -X POST \
  "${DISPATCH_URL}" \
  --data "$REQUEST_BODY")

if [[ "$http_status" != "204" ]]; then
  echo "Error: failed to trigger workflow (HTTP ${http_status})." >&2
  exit 1
fi

echo "Workflow dispatch created."

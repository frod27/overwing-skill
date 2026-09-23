#!/usr/bin/env bash
# Overwing helper for agents. Requires curl. Uses OVERWING_API_KEY unless the
# subcommand is `signup`. Prints JSON to stdout; non-2xx responses exit 1 with
# the API's {"error": "..."} body on stderr.
set -euo pipefail

BASE_URL="${OVERWING_BASE_URL:-https://overwing.ai}"
RULE_SET="content-safety"

usage() {
  cat >&2 <<USAGE
Usage:
  overwing.sh evaluate [--rule-set <slug>] "<text>"     score one text (or read text from stdin with "-")
  overwing.sh batch    [--rule-set <slug>]              JSON lines on stdin: {"id":"a","input":"..."}
  overwing.sh usage                                     today's quota and remaining checks
  overwing.sh whoami                                    which organization this key belongs to
  overwing.sh signup <email> <password>                 create an account and print the API key (once)
  overwing.sh terms                                     pay-per-request price and network (x402)
USAGE
  exit 2
}

json_escape() {
  # Escape a string for inclusion in JSON without requiring jq.
  python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))' 2>/dev/null || {
    local s; s=$(cat); s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//$'\n'/\\n}; s=${s//$'\t'/\\t}; printf '"%s"' "$s"
  }
}

require_key() {
  if [ -z "${OVERWING_API_KEY:-}" ]; then
    echo '{"error":"OVERWING_API_KEY is not set. Ask your human for a key (https://overwing.ai/login) or run: overwing.sh signup <email> <password>"}' >&2
    exit 1
  fi
}

call() {
  # call <method> <path> [json-body]
  local method="$1" path="$2" body="${3:-}" tmp code
  tmp=$(mktemp)
  if [ -n "$body" ]; then
    code=$(curl -sS -m 60 -o "$tmp" -w '%{http_code}' -X "$method" "$BASE_URL$path" \
      -H "Authorization: Bearer ${OVERWING_API_KEY:-}" -H "Content-Type: application/json" -H "Accept: application/json" \
      -H "User-Agent: overwing-skill/1.0 (openclaw)" --data-binary "$body")
  else
    code=$(curl -sS -m 60 -o "$tmp" -w '%{http_code}' -X "$method" "$BASE_URL$path" \
      -H "Authorization: Bearer ${OVERWING_API_KEY:-}" -H "Accept: application/json" -H "User-Agent: overwing-skill/1.0 (openclaw)")
  fi
  if [ "${code:0:1}" = "2" ]; then cat "$tmp"; echo; rm -f "$tmp"; return 0; fi
  cat "$tmp" >&2; echo >&2; rm -f "$tmp"; return 1
}

cmd="${1:-}"; shift || true
case "$cmd" in
  evaluate)
    require_key
    while [ $# -gt 0 ]; do
      case "$1" in
        --rule-set) RULE_SET="$2"; shift 2 ;;
        -) text=$(cat); shift ;;
        *) text="$1"; shift ;;
      esac
    done
    [ -n "${text:-}" ] || usage
    body=$(printf '{"input":%s,"rule_set":%s,"metadata":{"source":"openclaw-skill"}}' "$(printf '%s' "$text" | json_escape)" "$(printf '%s' "$RULE_SET" | json_escape)")
    call POST /api/v1/evaluate "$body"
    ;;
  batch)
    require_key
    while [ $# -gt 0 ]; do case "$1" in --rule-set) RULE_SET="$2"; shift 2 ;; *) usage ;; esac; done
    items=$(grep -v '^\s*$' | paste -sd, -)
    [ -n "$items" ] || usage
    call POST /api/v1/evaluate/batch "{\"rule_set\":$(printf '%s' "$RULE_SET" | json_escape),\"items\":[$items]}"
    ;;
  usage) require_key; call GET "/api/v1/usage?days=1" ;;
  whoami) require_key; call GET /api/v1/me ;;
  signup)
    [ $# -ge 2 ] || usage
    body=$(printf '{"email":%s,"password":%s,"org_name":"OpenClaw agent"}' "$(printf '%s' "$1" | json_escape)" "$(printf '%s' "$2" | json_escape)")
    OVERWING_API_KEY="" call POST /api/v1/signup "$body"
    ;;
  terms) OVERWING_API_KEY="" call GET /api/x402/evaluate ;;
  *) usage ;;
esac

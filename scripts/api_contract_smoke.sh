#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${API_BASE_URL:-}" || -z "${API_TEST_EMAIL:-}" || -z "${API_TEST_PASSWORD:-}" ]]; then
  echo "Missing required env vars: API_BASE_URL, API_TEST_EMAIL, API_TEST_PASSWORD"
  echo "Configure them as GitHub Actions secrets."
  exit 1
fi

assert_json_has_keys() {
  local payload="$1"
  shift
  python3 - "$payload" "$@" << 'PY'
import json
import sys

payload = json.loads(sys.argv[1])
keys = sys.argv[2:]
missing = [k for k in keys if k not in payload]
if missing:
    raise SystemExit(f"Missing keys: {', '.join(missing)}")
print("OK")
PY
}

request_json() {
  local method="$1"
  local url="$2"
  local token="${3:-}"
  local body="${4:-}"

  local curl_args=("-sS" "-X" "$method" "$url" "-H" "Content-Type: application/json")
  if [[ -n "$token" ]]; then
    curl_args+=("-H" "Authorization: Bearer $token")
  fi
  if [[ -n "$body" ]]; then
    curl_args+=("-d" "$body")
  fi

  curl "${curl_args[@]}"
}

echo "Logging in to ${API_BASE_URL}..."
login_payload=$(request_json "POST" "${API_BASE_URL}/auth/login" "" "{\"email\":\"${API_TEST_EMAIL}\",\"password\":\"${API_TEST_PASSWORD}\"}")
assert_json_has_keys "$login_payload" token >/dev/null

TOKEN=$(python3 - "$login_payload" << 'PY'
import json
import sys
obj = json.loads(sys.argv[1])
print(obj["token"])
PY
)

if [[ -z "$TOKEN" ]]; then
  echo "Failed to get auth token"
  exit 1
fi

echo "Checking /me"
me_payload=$(request_json "GET" "${API_BASE_URL}/me" "$TOKEN")
assert_json_has_keys "$me_payload" user tenant >/dev/null

echo "Checking /inventory/on-hand"
on_hand_payload=$(request_json "GET" "${API_BASE_URL}/inventory/on-hand" "$TOKEN")
assert_json_has_keys "$on_hand_payload" onHand >/dev/null

echo "Checking /requests"
requests_payload=$(request_json "GET" "${API_BASE_URL}/requests" "$TOKEN")
assert_json_has_keys "$requests_payload" requests >/dev/null

echo "Checking /inventory/forecast/latest"
forecast_payload=$(request_json "GET" "${API_BASE_URL}/inventory/forecast/latest?ensureFresh=1" "$TOKEN")
assert_json_has_keys "$forecast_payload" forecasts >/dev/null

echo "Checking /orders"
orders_payload=$(request_json "GET" "${API_BASE_URL}/orders" "$TOKEN")
assert_json_has_keys "$orders_payload" orders >/dev/null

echo "Checking /vendors"
vendors_payload=$(request_json "GET" "${API_BASE_URL}/vendors" "$TOKEN")
assert_json_has_keys "$vendors_payload" vendors >/dev/null

echo "All API contract smoke checks passed."

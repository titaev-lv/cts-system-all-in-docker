#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

ASSET_PATH="${WEB_UI_SMOKE_ASSET_PATH:-/assets/javascripts/ct.js}"
PROXY_BASE_URL="${WEB_UI_PROXY_URL:-https://localhost}"
DIRECT_BASE_URL="${WEB_UI_DIRECT_URL:-http://localhost:8082}"
LOGIN_USER="${WEB_UI_SMOKE_LOGIN_USER:-}"
LOGIN_PASS="${WEB_UI_SMOKE_LOGIN_PASS:-}"

FAILURES=0
SKIPS=0

log() {
  printf '[smoke-web-ui] %s\n' "$*"
}

ok() {
  printf '[smoke-web-ui] ✅ %s\n' "$*"
}

warn() {
  printf '[smoke-web-ui] ⚠️  %s\n' "$*"
}

fail() {
  printf '[smoke-web-ui] ❌ %s\n' "$*"
  FAILURES=$((FAILURES + 1))
}

check_http_code() {
  local expected="$1"
  local got="$2"
  local label="$3"
  if [[ "$got" == "$expected" ]]; then
    ok "$label (HTTP $got)"
  else
    fail "$label (expected HTTP $expected, got $got)"
  fi
}

log "Bringing up direct profile (web-ui-direct)..."
docker compose --profile direct up -d web-ui-direct >/dev/null

DIRECT_ASSET_CODE="$(curl -sS -o /tmp/webui-direct-asset.out -w '%{http_code}' "${DIRECT_BASE_URL}${ASSET_PATH}")"
check_http_code 200 "$DIRECT_ASSET_CODE" "Direct mode static is served"

log "Bringing up proxy profile (nginx + web-ui)..."
docker compose --profile proxy up -d web-ui nginx >/dev/null

PROXY_ASSET_HEADERS="$(mktemp)"
PROXY_ASSET_CODE="$(curl -ksS --http2 -D "$PROXY_ASSET_HEADERS" -o /tmp/webui-proxy-asset.out -w '%{http_code}' "${PROXY_BASE_URL}${ASSET_PATH}")"
check_http_code 200 "$PROXY_ASSET_CODE" "Proxy mode static is served"

if grep -iq '^server: nginx' "$PROXY_ASSET_HEADERS"; then
  ok "Proxy static response is served by nginx"
else
  fail "Proxy static response is not identified as nginx"
fi

BACKEND_STATIC_CHECK="$(docker compose --profile proxy exec -T nginx sh -lc "wget -qS -O /tmp/backend-asset.out 'http://web-ui:8080${ASSET_PATH}' 2>&1 || true")"
if echo "$BACKEND_STATIC_CHECK" | grep -q 'HTTP/1.1 404'; then
  ok "Gin static is disabled in proxy mode (backend returns 404 for /assets)"
else
  fail "Expected backend /assets to return 404 in proxy mode"
fi

RID="smoke-rid-$(date +%s)"
RID_HEADERS="$(mktemp)"
RID_CODE="$(curl -ksS --http2 -H "X-Request-ID: ${RID}" -D "$RID_HEADERS" -o /tmp/webui-healthz.out -w '%{http_code}' "${PROXY_BASE_URL}/healthz")"
check_http_code 200 "$RID_CODE" "Proxy /healthz is reachable"

RESP_RID="$(awk 'tolower($1)=="x-request-id:" {gsub("\r","",$2); print $2; exit}' "$RID_HEADERS")"
if [[ -n "$RESP_RID" ]]; then
  ok "Response contains X-Request-ID (${RESP_RID})"
else
  fail "Response does not contain X-Request-ID"
fi

WEBUI_LOGS="$(docker compose --profile proxy logs --tail=200 web-ui)"
if [[ -n "$RESP_RID" ]] && echo "$WEBUI_LOGS" | grep -q "\"request_id\":\"${RESP_RID}\""; then
  ok "X-Request-ID is preserved into web-ui-go logs"
else
  fail "Could not find response request_id in web-ui-go logs"
fi

if [[ -n "$LOGIN_USER" && -n "$LOGIN_PASS" ]]; then
  log "Running secure-cookie check via /auth/login (rememberme=on)..."
  LOGIN_HEADERS="$(mktemp)"
  LOGIN_BODY="$(mktemp)"
  curl -ksS --http2 \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data "username=${LOGIN_USER}&pwd=${LOGIN_PASS}&rememberme=on" \
    -D "$LOGIN_HEADERS" -o "$LOGIN_BODY" \
    "${PROXY_BASE_URL}/auth/login" >/dev/null

  if grep -q '"success":true' "$LOGIN_BODY"; then
    if grep -Ei '^Set-Cookie: (Login|CTToken)=' "$LOGIN_HEADERS" | grep -qi 'Secure'; then
      ok "Remember-me cookies are marked Secure behind proxy HTTPS"
    else
      fail "Remember-me cookies were set but missing Secure attribute"
    fi
  else
    fail "Secure-cookie check failed: login was not successful (provide valid WEB_UI_SMOKE_LOGIN_*)"
  fi
else
  SKIPS=$((SKIPS + 1))
  warn "Secure-cookie check skipped (set WEB_UI_SMOKE_LOGIN_USER and WEB_UI_SMOKE_LOGIN_PASS)"
fi

HTTP_REDIRECT_HEADERS="$(mktemp)"
curl -sS -D "$HTTP_REDIRECT_HEADERS" -o /dev/null "http://localhost/login"
if grep -q '^HTTP/1.1 301' "$HTTP_REDIRECT_HEADERS" && grep -qi '^Location: https://localhost/login' "$HTTP_REDIRECT_HEADERS"; then
  ok "HTTP to HTTPS redirect is correct for /login"
else
  fail "HTTP to HTTPS redirect check failed for /login"
fi

log "Smoke checks finished: failures=${FAILURES}, skipped=${SKIPS}"
if [[ "$FAILURES" -ne 0 ]]; then
  exit 1
fi

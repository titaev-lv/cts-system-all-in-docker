#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR/services/cts-core"

exec ./tests/smoke_phase2_ws_lifecycle.sh "$@"

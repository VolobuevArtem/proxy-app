#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
META="${ROOT_DIR}/out/server_meta.json"

if [[ ! -f "${META}" ]]; then
  echo "Не найден ${META}" >&2
  exit 1
fi

python3 - "${META}" <<'PY'
import json, sys
meta=json.load(open(sys.argv[1], "r", encoding="utf-8"))
for u in meta.get("users", []):
    print(u.get("name"))
PY


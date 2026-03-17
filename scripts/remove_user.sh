#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"
META="${OUT_DIR}/server_meta.json"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Запустите от root: sudo bash scripts/remove_user.sh <name>" >&2
  exit 1
fi

NAME="${1:-}"
if [[ -z "${NAME}" ]]; then
  echo "Usage: sudo bash scripts/remove_user.sh <name>" >&2
  exit 2
fi

if [[ ! -f "${META}" ]]; then
  echo "Не найден ${META}" >&2
  exit 1
fi

python3 - "${META}" "${NAME}" <<'PY'
import json, sys
path, name = sys.argv[1], sys.argv[2]
meta=json.load(open(path, "r", encoding="utf-8"))
users=meta.get("users", [])
new=[u for u in users if u.get("name") != name]
if len(new) == len(users):
    raise SystemExit(f"User not found: {name}")
meta["users"]=new
json.dump(meta, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("ok")
PY

rm -f "${OUT_DIR}/${NAME}.client.json" 2>/dev/null || true

python3 "${ROOT_DIR}/scripts/render_templates.py" \
  "${ROOT_DIR}/server/config.template.json" \
  "${META}" \
  /etc/sing-box/config.json

systemctl restart sing-box

echo "Удалено: ${NAME}"


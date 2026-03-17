#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"
META="${OUT_DIR}/server_meta.json"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Запустите от root: sudo bash scripts/add_user.sh <name>" >&2
  exit 1
fi

NAME="${1:-}"
if [[ -z "${NAME}" ]]; then
  echo "Usage: sudo bash scripts/add_user.sh <name>" >&2
  exit 2
fi

if [[ ! -f "${META}" ]]; then
  echo "Не найден ${META}. Сначала запустите: sudo bash scripts/server_install.sh" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"

SS_PASSWORD="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(24))
PY
)"

python3 - "${META}" "${NAME}" "${SS_PASSWORD}" <<'PY'
import json, sys
path, name, pw = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path, "r", encoding="utf-8") as f:
    meta = json.load(f)
users = meta.get("users", [])
if any(u.get("name") == name for u in users):
    raise SystemExit(f"User already exists: {name}")
users.append({"name": name, "ss_password": pw})
meta["users"] = users
with open(path, "w", encoding="utf-8") as f:
    json.dump(meta, f, ensure_ascii=False, indent=2)
    f.write("\n")
print(pw)
PY

CLIENT_META="$(python3 - <<PY
import json
meta=json.load(open("${META}", "r", encoding="utf-8"))
meta["ss_password"]="${SS_PASSWORD}"
print(json.dumps(meta, ensure_ascii=False))
PY
)"

TMP_CLIENT_META="${OUT_DIR}/.${NAME}.tmp.meta.json"
echo "${CLIENT_META}" > "${TMP_CLIENT_META}"

python3 "${ROOT_DIR}/scripts/render_templates.py" \
  "${ROOT_DIR}/client/config.template.json" \
  "${TMP_CLIENT_META}" \
  "${OUT_DIR}/${NAME}.client.json"

rm -f "${TMP_CLIENT_META}"

python3 "${ROOT_DIR}/scripts/render_templates.py" \
  "${ROOT_DIR}/server/config.template.json" \
  "${META}" \
  /etc/sing-box/config.json

systemctl restart sing-box

echo "Готово: ${OUT_DIR}/${NAME}.client.json"


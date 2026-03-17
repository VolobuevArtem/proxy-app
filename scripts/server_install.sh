#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/out"

if [[ "${EUID}" -ne 0 ]]; then
  echo "Запустите от root: sudo bash scripts/server_install.sh" >&2
  exit 1
fi

mkdir -p "${OUT_DIR}"

META="${OUT_DIR}/server_meta.json"

if [[ ! -f "${META}" ]]; then
  echo "==> Создаю ${META}"
  read -r -p "HOST (домен или IP VPS): " HOST
  read -r -p "SNI (например www.cloudflare.com): " SNI
  read -r -p "PUBLIC_PORT (обычно 443): " PUBLIC_PORT
  PUBLIC_PORT="${PUBLIC_PORT:-443}"

  INNER_PORT=24443
  SS_METHOD="2022-blake3-aes-128-gcm"
  SHADOWTLS_PASSWORD="$(python3 - <<'PY'
import secrets
print(secrets.token_urlsafe(24))
PY
)"

  cat > "${META}" <<EOF
{
  "host": "${HOST}",
  "sni": "${SNI}",
  "public_port": ${PUBLIC_PORT},
  "inner_port": ${INNER_PORT},
  "ss_method": "${SS_METHOD}",
  "shadowtls_password": "${SHADOWTLS_PASSWORD}",
  "users": []
}
EOF
  echo "==> ShadowTLS password сохранён в ${META}"
fi

echo "==> Скачиваю sing-box (latest)..."
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

ARCH="$(uname -m)"
case "${ARCH}" in
  x86_64|amd64) SB_ARCH="amd64" ;;
  aarch64|arm64) SB_ARCH="arm64" ;;
  *) echo "Неизвестная архитектура: ${ARCH}" >&2; exit 1 ;;
esac

apt-get update -y
apt-get install -y curl unzip

# Используем GitHub releases: скачиваем последний linux-ARCH
LATEST_URL="$(curl -fsSL https://api.github.com/repos/SagerNet/sing-box/releases/latest | \
  python3 -c "import sys, json; d=json.load(sys.stdin); \
print([a['browser_download_url'] for a in d.get('assets',[]) if ('linux-${SB_ARCH}' in a['name'] and a['name'].endswith('.zip'))][0])")"

curl -fL "${LATEST_URL}" -o "${TMP_DIR}/sing-box.zip"
unzip -o "${TMP_DIR}/sing-box.zip" -d "${TMP_DIR}" >/dev/null

SB_BIN="$(find "${TMP_DIR}" -type f -name sing-box | head -n 1)"
if [[ -z "${SB_BIN}" ]]; then
  echo "Не нашёл sing-box бинарник в архиве" >&2
  exit 1
fi

install -m 0755 "${SB_BIN}" /usr/local/bin/sing-box

echo "==> Рендерю /etc/sing-box/config.json"
mkdir -p /etc/sing-box

python3 "${ROOT_DIR}/scripts/render_templates.py" \
  "${ROOT_DIR}/server/config.template.json" \
  "${META}" \
  /etc/sing-box/config.json

echo "==> Ставлю systemd unit"
cat >/etc/systemd/system/sing-box.service <<'EOF'
[Unit]
Description=sing-box service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/sing-box run -c /etc/sing-box/config.json
Restart=on-failure
RestartSec=2
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable sing-box
systemctl restart sing-box

echo "==> Готово. Метаданные сервера: ${META}"
echo "==> Добавьте первого пользователя: sudo bash scripts/add_user.sh \"alice\""


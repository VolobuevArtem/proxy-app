# VPN “как HTTPS” на VPS (sing-box: Shadowsocks-2022 + ShadowTLS)

Цель: один конечный инструмент, где на iPhone/macOS вы **импортируете конфиг** и нажимаете **Connect**.

Что внутри:

- **Туннель**: Shadowsocks-2022 (multi-user на одном порту)
- **Маскировка под HTTPS**: ShadowTLS (выглядит как обычный TLS к выбранному SNI/домену)
- **Раздача доступа**: отдельный пользователь (имя + пароль), можно отозвать
- **VPN-режим на устройстве**: TUN (весь трафик устройства через туннель)
- **Локальные прокси** (опционально): SOCKS5 `127.0.0.1:1080` и HTTP `127.0.0.1:2080`

---

## Требования

### VPS

- Ubuntu 22.04/24.04 или Debian 12
- root
- открытый порт **443/tcp** (или ваш)
- домен (желательно) или IP

### Клиенты

- iOS: sing-box (клиент)
- macOS: sing-box (GUI/CLI)

---

## Установка на VPS

```bash
mkdir -p /opt/vpn-tool
cd /opt/vpn-tool
# скопируйте сюда содержимое репозитория
sudo bash scripts/server_install.sh
```

Проверка:

```bash
systemctl status sing-box --no-pager
```

---

## Выдать доступ пользователю

```bash
cd /opt/vpn-tool
sudo bash scripts/add_user.sh "alice"
```

Файл для пользователя:

- `out/alice.client.json` (импортировать в sing-box на iOS/macOS)

---

## Отозвать доступ

```bash
cd /opt/vpn-tool
sudo bash scripts/remove_user.sh "alice"
```

---

## Подключение iPhone / macOS

Импортируйте `out/<имя>.client.json` в sing-box и нажмите **Connect**.

### iPhone (iOS) — шаги импорта

- Передайте файл `out/<имя>.client.json` на iPhone (AirDrop / Files / iCloud Drive / мессенджер).
- Откройте приложение **sing-box**.
- Откройте раздел профилей (Profiles) → **Import**.
- Выберите файл `*.client.json`.
- Включите профиль и нажмите **Connect**.
- При первом подключении iOS попросит добавить VPN‑профиль — подтвердите.

### macOS — шаги импорта

#### Вариант A: GUI

- Откройте приложение **sing-box**.
- Profiles → **Import** → выберите `out/<имя>.client.json`.
- Нажмите **Connect**.

#### Вариант B: CLI

```bash
sing-box run -c /path/to/<имя>.client.json
```

---

## Локальный прокси (контроль трафика)

Локальные прокси доступны всегда, пока sing-box запущен:

- SOCKS5: `127.0.0.1:1080`
- HTTP: `127.0.0.1:2080`


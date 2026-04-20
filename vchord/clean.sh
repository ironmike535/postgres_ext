#!/usr/bin/env bash
set -euo pipefail

echo "===> Полная очистка перед сборкой"

# Удаление временных директорий
rm -rf /tmp/vchord_build
rm -rf /tmp/VectorChord*

# Очистка Rust кэша
rm -rf /root/.cargo
rm -rf /root/.pgrx
rm -rf /root/.rustup

# Очистка Docker
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker system prune -f 2>/dev/null || true

echo "✅ Очистка завершена"

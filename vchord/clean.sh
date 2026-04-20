#!/usr/bin/env bash
set -euo pipefail

echo "===> Полная очистка перед сборкой"

# Удаление временных директорий
rm -rf /tmp/vchord_build
rm -rf /tmp/VectorChord
rm -rf /root/.cargo

# Остановка и удаление контейнеров
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true

# Удаление образа
docker rmi rockylinux:8 -f 2>/dev/null || true

# Очистка кэша Docker
docker system prune -f 2>/dev/null || true

echo "✅ Очистка завершена"

#!/usr/bin/env bash
set -euo pipefail

echo "===> Полная очистка"

# Остановка PostgreSQL
systemctl stop postgresql-14 2>/dev/null || true

# Удаление расширения из БД
sudo -u postgres psql -h /tmp -d postgres -c "DROP EXTENSION IF EXISTS vchord CASCADE;" 2>/dev/null || true
sudo -u postgres psql -h /tmp -d postgres -c "DROP EXTENSION IF EXISTS vector CASCADE;" 2>/dev/null || true

# Удаление RPM пакетов
dnf remove -y vchord_14 pgvector_14 2>/dev/null || true

# Удаление файлов вручную
rm -f /usr/pgsql-14/lib/vchord.so
rm -f /usr/pgsql-14/share/extension/vchord*

# Очистка shared_preload_libraries
PG_CONF="/var/lib/pgsql/14/data/postgresql.conf"
sed -i 's/,vchord//g' $PG_CONF
sed -i 's/vchord,//g' $PG_CONF
sed -i 's/vchord//g' $PG_CONF
sed -i 's/,vector//g' $PG_CONF
sed -i 's/vector,//g' $PG_CONF

# Очистка временных директорий
rm -rf /tmp/vchord_build
rm -rf /tmp/VectorChord
rm -rf /root/.cargo

# Очистка Docker
docker stop $(docker ps -aq) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker rmi rockylinux:8 -f 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# Перезапуск PostgreSQL
systemctl start postgresql-14

echo "✅ Полная очистка завершена"

#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Установка векторных расширений
# Порядок: pgvector -> pgvectorscale -> vchord
# ============================================

PGVER=15
SOCKET_DIR="/tmp"
PG_CONF="/var/lib/pgsql/${PGVER}/data/postgresql.conf"

echo "============================================"
echo "Установка векторных расширений"
echo "============================================"

# 1. Установка pgvector
echo ""
echo "===> 1. Установка pgvector"
dnf install -y pgvector_${PGVER}
echo "✅ pgvector установлен"

# 2. Установка pgvectorscale
echo ""
echo "===> 2. Установка pgvectorscale"
dnf install -y https://github.com/ironmike535/postgres_ext/raw/refs/heads/main/pgvectorscale/rpms/el8/pg${PGVER}/pgvectorscale_${PGVER}-0.9.0-1.el8.x86_64.rpm
echo "✅ pgvectorscale установлен"

# 3. Установка vchord
echo ""
echo "===> 3. Установка vchord"
dnf install -y https://github.com/ironmike535/postgres_ext/raw/refs/heads/main/vchord/rpms/el8/pg${PGVER}/vchord_${PGVER}-1.1.1-1.el8.x86_64.rpm
echo "✅ vchord установлен"

# 4. Добавление расширений в shared_preload_libraries
echo ""
echo "===> 4. Настройка shared_preload_libraries"

# Добавляем vector
if ! grep -q "vector" $PG_CONF; then
    sed -i "s/shared_preload_libraries = '\(.*\)'/shared_preload_libraries = '\1,vector'/" $PG_CONF
fi

# Добавляем vectorscale
if ! grep -q "vectorscale" $PG_CONF; then
    sed -i "s/shared_preload_libraries = '\(.*\)'/shared_preload_libraries = '\1,vectorscale'/" $PG_CONF
fi

# Добавляем vchord
if ! grep -q "vchord" $PG_CONF; then
    sed -i "s/shared_preload_libraries = '\(.*\)'/shared_preload_libraries = '\1,vchord'/" $PG_CONF
fi

echo "✅ shared_preload_libraries настроен"

# 5. Перезапуск PostgreSQL
echo ""
echo "===> 5. Перезапуск PostgreSQL"
systemctl restart postgresql-${PGVER}
sleep 5
echo "✅ PostgreSQL перезапущен"

# 6. Создание расширений в БД
echo ""
echo "===> 6. Создание расширений в базе данных"
sudo -u postgres psql -h ${SOCKET_DIR} -d postgres << EOF
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS vectorscale;
CREATE EXTENSION IF NOT EXISTS vchord;
EOF
echo "✅ Расширения созданы"

# 7. Проверка
echo ""
echo "===> 7. Проверка"
echo "shared_preload_libraries:"
sudo -u postgres psql -h ${SOCKET_DIR} -d postgres -c "SHOW shared_preload_libraries;"
echo ""
echo "Установленные расширения:"
sudo -u postgres psql -h ${SOCKET_DIR} -d postgres -c "SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'vectorscale', 'vchord');"

echo ""
echo "============================================"
echo "✅ Установка завершена"
echo "============================================"

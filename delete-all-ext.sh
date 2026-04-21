#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Полное удаление векторных расширений
# ============================================

PGVER=15
SOCKET_DIR="/tmp"
PG_CONF="/var/lib/pgsql/${PGVER}/data/postgresql.conf"

echo "============================================"
echo "Полное удаление векторных расширений"
echo "============================================"

# 1. Удаление расширений из БД
echo ""
echo "===> 1. Удаление расширений из базы данных"
sudo -u postgres psql -h ${SOCKET_DIR} -d postgres << EOF
DROP EXTENSION IF EXISTS vectorscale CASCADE;
DROP EXTENSION IF EXISTS vchord CASCADE;
DROP EXTENSION IF EXISTS vector CASCADE;
EOF
echo "✅ Расширения удалены из БД"

# 2. Очистка shared_preload_libraries
echo ""
echo "===> 2. Очистка shared_preload_libraries"

# Полностью заменяем строку на правильную
sed -i "s/^shared_preload_libraries = .*/shared_preload_libraries = 'pg_stat_statements,auto_explain'/" $PG_CONF
echo "✅ shared_preload_libraries очищен"

# 3. Перезапуск PostgreSQL
echo ""
echo "===> 3. Перезапуск PostgreSQL"
systemctl restart postgresql-${PGVER}
sleep 5
echo "✅ PostgreSQL перезапущен"

# 4. Удаление RPM пакетов
echo ""
echo "===> 4. Удаление RPM пакетов"
dnf remove -y pgvector_${PGVER} pgvectorscale_${PGVER} vchord_${PGVER} 2>/dev/null || echo "Пакеты не найдены или уже удалены"

# 5. Проверка
echo ""
echo "===> 5. Проверка"
echo "shared_preload_libraries:"
sudo -u postgres psql -h ${SOCKET_DIR} -d postgres -c "SHOW shared_preload_libraries;"
echo ""
echo "Оставшиеся расширения:"
sudo -u postgres psql -h ${SOCKET_DIR} -d postgres -c "SELECT extname FROM pg_extension WHERE extname IN ('vector', 'vectorscale', 'vchord');" || echo "✅ Расширений нет"

echo ""
echo "============================================"
echo "✅ Полное удаление завершено"
echo "============================================"

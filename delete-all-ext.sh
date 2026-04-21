#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Полное удаление векторных расширений
# Использование: ./delete-all-ext.sh <версия>
# Пример: ./delete-all-ext.sh 14
# ============================================

# Проверка аргумента
if [ $# -eq 0 ]; then
    echo "❌ Ошибка: укажите версию PostgreSQL"
    echo "Использование: $0 <версия>"
    echo "Пример: $0 14"
    exit 1
fi

PGVER=$1
SOCKET_DIR="/tmp"
PG_CONF="/var/lib/pgsql/${PGVER}/data/postgresql.conf"
LIB_DIR="/usr/pgsql-${PGVER}/lib"
EXTENSION_DIR="/usr/pgsql-${PGVER}/share/extension"

echo "============================================"
echo "Полное удаление векторных расширений для PostgreSQL ${PGVER}"
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

# 5. Проверка удаления файлов
echo ""
echo "===> 5. Проверка удаления файлов"

# Проверка lib директории
echo "Проверка ${LIB_DIR}:"
if ls ${LIB_DIR}/vector* 1>/dev/null 2>&1 || ls ${LIB_DIR}/vectorscale* 1>/dev/null 2>&1 || ls ${LIB_DIR}/vchord* 1>/dev/null 2>&1; then
    echo "❌ В директории ${LIB_DIR} остались файлы:"
    ls -la ${LIB_DIR}/vector* ${LIB_DIR}/vectorscale* ${LIB_DIR}/vchord* 2>/dev/null
else
    echo "✅ В директории ${LIB_DIR} файлы vector, vectorscale, vchord отсутствуют"
fi

# Проверка extension директории
echo ""
echo "Проверка ${EXTENSION_DIR}:"
if ls ${EXTENSION_DIR}/vector* 1>/dev/null 2>&1 || ls ${EXTENSION_DIR}/vectorscale* 1>/dev/null 2>&1 || ls ${EXTENSION_DIR}/vchord* 1>/dev/null 2>&1; then
    echo "❌ В директории ${EXTENSION_DIR} остались файлы:"
    ls -la ${EXTENSION_DIR}/vector* ${EXTENSION_DIR}/vectorscale* ${EXTENSION_DIR}/vchord* 2>/dev/null
else
    echo "✅ В директории ${EXTENSION_DIR} файлы vector, vectorscale, vchord отсутствуют"
fi

# 6. Проверка shared_preload_libraries в БД
echo ""
echo "===> 6. Проверка shared_preload_libraries"
sudo -u postgres psql -h ${SOCKET_DIR} -d postgres -c "SHOW shared_preload_libraries;"

# 7. Проверка оставшихся расширений в БД
echo ""
echo "===> 7. Проверка оставшихся расширений"
sudo -u postgres psql -h ${SOCKET_DIR} -d postgres -c "SELECT extname FROM pg_extension WHERE extname IN ('vector', 'vectorscale', 'vchord');" || echo "✅ Расширений нет"

echo ""
echo "============================================"
echo "✅ Полное удаление завершено для PostgreSQL ${PGVER}"
echo "============================================"

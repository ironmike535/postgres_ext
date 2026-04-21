#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Полное удаление векторных расширений на лидере Patroni
# Использование: ./delete-all-ext-patroni-leader.sh <версия>
# Пример: ./delete-all-ext-patroni-leader.sh 14
# ============================================

# Проверка аргумента
if [ $# -eq 0 ]; then
    echo "❌ Ошибка: укажите версию PostgreSQL"
    echo "Использование: $0 <версия>"
    echo "Пример: $0 14"
    exit 1
fi

PGVER=$1
CLUSTER_NAME="ha_pgsql"
PATRONI_CONFIG="/etc/patroni/patroni_postgres.yml"
LIB_DIR="/usr/pgsql-${PGVER}/lib"
EXTENSION_DIR="/usr/pgsql-${PGVER}/share/extension"

echo "============================================"
echo "Полное удаление векторных расширений на лидере Patroni для PostgreSQL ${PGVER}"
echo "============================================"

# 1. Удаление расширений из БД
echo ""
echo "===> 1. Удаление расширений из базы данных"
sudo -u postgres psql -h /tmp -d postgres << EOF
DROP EXTENSION IF EXISTS vectorscale CASCADE;
DROP EXTENSION IF EXISTS vchord CASCADE;
DROP EXTENSION IF EXISTS vector CASCADE;
EOF
echo "✅ Расширения удалены из БД"

# 2. Очистка shared_preload_libraries в конфиге Patroni
echo ""
echo "===> 2. Очистка shared_preload_libraries в Patroni"

# Полностью заменяем строку на правильную
sed -i "s/shared_preload_libraries: '\(.*\)'/shared_preload_libraries: 'pg_stat_statements,auto_explain'/" $PATRONI_CONFIG
echo "✅ shared_preload_libraries очищен в Patroni"

# 3. Применение конфигурации Patroni
echo ""
echo "===> 3. Применение конфигурации Patroni"
patronictl edit-config --apply $PATRONI_CONFIG --force
echo "✅ Конфигурация применена"

# 4. Перезагрузка Patroni
echo ""
echo "===> 4. Перезагрузка Patroni (reload)"
patronictl reload $CLUSTER_NAME
echo "✅ Patroni перезагружен"

echo "===> Ожидание 11 секунд"
sleep 11

# 5. Первый перезапуск Patroni
echo ""
echo "===> 5. Первый перезапуск Patroni"
patronictl restart $CLUSTER_NAME --force
echo "✅ Первый перезапуск выполнен"

echo "===> Ожидание 11 секунд"
sleep 11

# 6. Второй перезапуск Patroni
echo ""
echo "===> 6. Второй перезапуск Patroni"
patronictl restart $CLUSTER_NAME --force
echo "✅ Второй перезапуск выполнен"

echo "===> Ожидание 11 секунд"
sleep 11

# 7. Вывод статуса кластера
echo ""
echo "===> 7. Статус кластера Patroni"
patronictl list

# 8. Проверка shared_preload_libraries в БД
echo ""
echo "===> 8. Проверка shared_preload_libraries в БД"
sudo -u postgres psql -h /tmp -d postgres -c "SHOW shared_preload_libraries;"

# 9. Проверка оставшихся расширений в БД
echo ""
echo "===> 9. Проверка оставшихся расширений"
sudo -u postgres psql -h /tmp -d postgres -c "SELECT extname FROM pg_extension WHERE extname IN ('vector', 'vectorscale', 'vchord');" || echo "✅ Расширений нет"

# 10. Удаление RPM пакетов
echo ""
echo "===> 10. Удаление RPM пакетов"
dnf remove -y pgvector_${PGVER} pgvectorscale_${PGVER} vchord_${PGVER} 2>/dev/null || echo "Пакеты не найдены или уже удалены"

# 11. Проверка удаления файлов
echo ""
echo "===> 11. Проверка удаления файлов"

# Проверка lib директории
echo "Проверка ${LIB_DIR}:"
if ls ${LIB_DIR}/vector* 1>/dev/null 2>&1 || ls ${LIB_DIR}/vectorscale* 1>/dev/null 2>&1 || ls ${LIB_DIR}/vchord* 1>/dev/null 2>&1; then
    echo "❌ В директории ${LIB_DIR} остались файлы:"
    ls -la ${LIB_DIR}/vector* ${LIB_DIR}/vectorscale* ${LIB_DIR}/vchord* 2>/dev/null
else
    echo "✅ Директория ${LIB_DIR} пуста (файлы vector, vectorscale, vchord отсутствуют)"
fi

# Проверка extension директории
echo ""
echo "Проверка ${EXTENSION_DIR}:"
if ls ${EXTENSION_DIR}/vector* 1>/dev/null 2>&1 || ls ${EXTENSION_DIR}/vectorscale* 1>/dev/null 2>&1 || ls ${EXTENSION_DIR}/vchord* 1>/dev/null 2>&1; then
    echo "❌ В директории ${EXTENSION_DIR} остались файлы:"
    ls -la ${EXTENSION_DIR}/vector* ${EXTENSION_DIR}/vectorscale* ${EXTENSION_DIR}/vchord* 2>/dev/null
else
    echo "✅ Директория ${EXTENSION_DIR} пуста (файлы vector, vectorscale, vchord отсутствуют)"
fi

echo ""
echo "============================================"
echo "✅ Полное удаление векторных расширений на лидере Patroni для PostgreSQL ${PGVER} завершено"
echo "============================================"

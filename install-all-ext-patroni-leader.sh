#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Установка векторных расширений на репликах Patroni
# Использование: ./install-patroni-replicas.sh <версия>
# Пример: ./install-patroni-replicas.sh 14
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

echo "============================================"
echo "Установка векторных расширений на репликах Patroni для PostgreSQL ${PGVER}"
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

# 4. Добавление расширений в shared_preload_libraries в конфиге Patroni
echo ""
echo "===> 4. Настройка shared_preload_libraries в Patroni"

# Добавляем vector
if ! grep -q "vector" $PATRONI_CONFIG; then
    sed -i "s/shared_preload_libraries: '\(.*\)'/shared_preload_libraries: '\1,vector'/" $PATRONI_CONFIG
fi

# Добавляем vectorscale
if ! grep -q "vectorscale" $PATRONI_CONFIG; then
    sed -i "s/shared_preload_libraries: '\(.*\)'/shared_preload_libraries: '\1,vectorscale'/" $PATRONI_CONFIG
fi

# Добавляем vchord
if ! grep -q "vchord" $PATRONI_CONFIG; then
    sed -i "s/shared_preload_libraries: '\(.*\)'/shared_preload_libraries: '\1,vchord'/" $PATRONI_CONFIG
fi

echo "✅ shared_preload_libraries настроен в Patroni"

# 5. Применение конфигурации Patroni
echo ""
echo "===> 5. Применение конфигурации Patroni"
patronictl edit-config --apply $PATRONI_CONFIG --force
echo "✅ Конфигурация применена"

# 6. Перезагрузка Patroni
echo ""
echo "===> 6. Перезагрузка Patroni (reload)"
patronictl reload $CLUSTER_NAME --force
echo "✅ Patroni перезагружен"

echo "===> Ожидание 11 секунд"
sleep 11

# 7. Первый перезапуск Patroni
echo ""
echo "===> 7. Первый перезапуск Patroni"
patronictl restart $CLUSTER_NAME --force
echo "✅ Первый перезапуск выполнен"

echo "===> Ожидание 11 секунд"
sleep 11

# 8. Второй перезапуск Patroni
echo ""
echo "===> 8. Второй перезапуск Patroni"
patronictl restart $CLUSTER_NAME --force
echo "✅ Второй перезапуск выполнен"

echo "===> Ожидание 11 секунд"
sleep 11

# 9. Вывод статуса кластера
echo ""
echo "===> 9. Статус кластера Patroni"
patronictl list

# 10. Проверка shared_preload_libraries в БД
echo ""
echo "===> 10. Проверка shared_preload_libraries в БД"
sudo -u postgres psql -h /tmp -d postgres -c "SHOW shared_preload_libraries;"

# 11. Создание расширений в БД (только на лидере)
echo ""
echo "===> 11. Создание расширений в базе данных"
sudo -u postgres psql -h /tmp -d postgres << EOF
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS vectorscale;
CREATE EXTENSION IF NOT EXISTS vchord;
EOF
echo "✅ Расширения созданы"

# 12. Проверка установленных расширений
echo ""
echo "===> 12. Проверка установленных расширений"
sudo -u postgres psql -h /tmp -d postgres -c "SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'vectorscale', 'vchord');"

echo ""
echo "============================================"
echo "✅ Установка векторных расширений на Patroni для PostgreSQL ${PGVER} завершена"
echo "============================================"

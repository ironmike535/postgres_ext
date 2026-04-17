#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Установка pgvector и pgvectorscale для PostgreSQL ${PGVER} patroni
# ============================================

PGVER=16
BUILD_DIR="/tmp/pgvectorscale_build/rhel8/pg${PGVER}"
PATRONI_CONFIG="/etc/patroni/patroni_postgres.yml"
CLUSTER_NAME="ha_pgsql"  # замени на имя твоего кластера

echo "===> Копирование файлов pgvectorscale"
if [[ -d "${BUILD_DIR}" ]]; then
    cp ${BUILD_DIR}/lib/vectorscale-*.so /usr/pgsql-${PGVER}/lib/
    cd /usr/pgsql-${PGVER}/lib/
    ln -sf vectorscale-*.so vectorscale.so
    cp ${BUILD_DIR}/extension/* /usr/pgsql-${PGVER}/share/extension/
    chown postgres:postgres /usr/pgsql-${PGVER}/lib/vectorscale*
    chown -R postgres:postgres /usr/pgsql-${PGVER}/share/extension/vectorscale*
    echo "✅ Файлы pgvectorscale скопированы"
else
    echo "❌ Директория ${BUILD_DIR} не найдена"
    exit 1
fi

echo "===> Добавление vectorscale в shared_preload_libraries (Patroni)"
if grep -q "shared_preload_libraries" "${PATRONI_CONFIG}"; then
    if ! grep -q "vectorscale" "${PATRONI_CONFIG}"; then
        sed -i "s/shared_preload_libraries: '\(.*\)'/shared_preload_libraries: '\1,vectorscale'/" "${PATRONI_CONFIG}"
        echo "✅ vectorscale добавлен в shared_preload_libraries"
    else
        echo "⚠️ vectorscale уже есть в shared_preload_libraries"
    fi
else
    echo "    shared_preload_libraries: 'vectorscale'" >> "${PATRONI_CONFIG}"
    echo "✅ shared_preload_libraries создан"
fi

echo "===> Применение конфигурации Patroni (reload)"
patronictl edit-config --apply /etc/patroni/patroni_postgres.yml --force
echo "✅ Конфигурация применена"

echo "===> Ожидание 11 секунд"
sleep 11

echo "===> Перезапуск Patroni (первый)"
patronictl restart ${CLUSTER_NAME} --force
echo "✅ Первый перезапуск выполнен"

echo "===> Ожидание 11 секунд"
sleep 11

echo "===> Перезапуск Patroni (второй)"
patronictl restart ${CLUSTER_NAME} --force
echo "✅ Второй перезапуск выполнен"

echo "===> Ожидание 11 секунд"
sleep 11

echo "===> Проверка версии PostgreSQL и настроек"
sudo -u postgres psql -h /tmp -d postgres << EOF
-- Версия PostgreSQL
SELECT version();

-- shared_preload_libraries
SHOW shared_preload_libraries;

-- Текущие расширения до установки
\dx
EOF

echo "===> Создание расширений в базе данных postgres"
sudo -u postgres psql -h /tmp -d postgres << EOF
-- Создание pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Создание pgvectorscale (зависит от vector)
CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;

-- Проверка установки расширений
SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'vectorscale');
EOF

echo "===> Финальный список расширений"
sudo -u postgres psql -h /tmp -d postgres -c "\dx"

echo ""
echo "============================================"
echo "✅ Установка завершена"
echo "============================================"
echo "Проверка:"
echo "  sudo -u postgres psql -h /tmp -c \"SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'vectorscale');\""
echo "  sudo -u postgres psql -h /tmp -c \"SHOW shared_preload_libraries;\""
echo "============================================"

#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Установка pgvector и pgvectorscale для PostgreSQL ${PGVER}
# ============================================

# ============================================
# Установка pgvector и pgvectorscale для PostgreSQL
# Использование: ./install.sh <версия>
# Пример: ./install.sh 14
# ============================================

# Проверка аргумента
if [ $# -eq 0 ]; then
    echo "❌ Ошибка: укажите версию PostgreSQL"
    echo "Использование: $0 <версия>"
    echo "Пример: $0 14"
    exit 1
fi

PGVER=$1
BUILD_DIR="/tmp/pgvectorscale_build/rhel8/pg${PGVER}"
SOCKET_DIR="/tmp"

echo "===> Установка pgvector (из репозитория)"
dnf install -y pgvector_${PGVER}

echo "===> Копирование файлов pgvectorscale"
if [[ -d "${BUILD_DIR}" ]]; then
    # Копирование библиотеки
    cp ${BUILD_DIR}/lib/vectorscale-*.so /usr/pgsql-${PGVER}/lib/
    cd /usr/pgsql-${PGVER}/lib/
    ln -sf vectorscale-*.so vectorscale.so

    # Копирование файлов расширения
    cp ${BUILD_DIR}/extension/* /usr/pgsql-${PGVER}/share/extension/

    # Права доступа
    chown postgres:postgres /usr/pgsql-${PGVER}/lib/vectorscale*
    chown -R postgres:postgres /usr/pgsql-${PGVER}/share/extension/vectorscale*

    echo "✅ Файлы pgvectorscale скопированы"
else
    echo "❌ Директория ${BUILD_DIR} не найдена"
    exit 1
fi

echo "===> Добавление vectorscale в shared_preload_libraries"
PG_CONF="/var/lib/pgsql/${PGVER}/data/postgresql.conf"

if grep -q "shared_preload_libraries" "${PG_CONF}"; then
    if ! grep -q "vectorscale" "${PG_CONF}"; then
        sed -i "s/shared_preload_libraries = '\(.*\)'/shared_preload_libraries = '\1,vectorscale'/" "${PG_CONF}"
        echo "✅ vectorscale добавлен в shared_preload_libraries"
    else
        echo "⚠️ vectorscale уже есть в shared_preload_libraries"
    fi
else
    echo "shared_preload_libraries = 'vectorscale'" >> "${PG_CONF}"
    echo "✅ shared_preload_libraries создан с vectorscale"
fi

echo "===> Перезапуск PostgreSQL"
systemctl restart postgresql-${PGVER}

echo "===> Ожидание запуска PostgreSQL"
sleep 5

echo "===> Проверка версии PostgreSQL и настроек"
sudo -u postgres psql -d postgres -h ${SOCKET_DIR} << EOF
-- Версия PostgreSQL
SELECT version();

-- Текущие расширения
\dx

-- shared_preload_libraries
SHOW shared_preload_libraries;
EOF

echo "===> Создание расширений в базе данных postgres"
sudo -u postgres psql -d postgres -h ${SOCKET_DIR} << EOF
-- Создание pgvector
CREATE EXTENSION IF NOT EXISTS vector;

-- Создание pgvectorscale (зависит от vector)
CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;

-- Проверка установки расширений
SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'vectorscale');

-- Еще раз список расширений после установки
\dx
EOF

echo ""
echo "============================================"
echo "✅ Установка завершена"
echo "============================================"
echo "Проверка:"
echo "  sudo -u postgres psql -h /tmp -c \"SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'vectorscale');\""
echo "  sudo -u postgres psql -h /tmp -c \"SHOW shared_preload_libraries;\""
echo "============================================"

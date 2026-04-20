#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Установка pgvector и pgvectorscale на репликах Patroni
# Использование: ./install_replica.sh <версия>
# Пример: ./install_replica.sh 14
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

echo "===> Установка для PostgreSQL версии ${PGVER} (реплика)"

# Проверка существования директории с собранными файлами
if [[ ! -d "${BUILD_DIR}" ]]; then
    echo "❌ Ошибка: директория ${BUILD_DIR} не найдена"
    echo "Сначала соберите pgvectorscale для версии ${PGVER}"
    exit 1
fi

echo "===> Установка pgvector (из репозитория)"
dnf install -y pgvector_${PGVER}

echo "===> Копирование файлов pgvectorscale"
cp ${BUILD_DIR}/lib/vectorscale-*.so /usr/pgsql-${PGVER}/lib/
cd /usr/pgsql-${PGVER}/lib/
ln -sf vectorscale-*.so vectorscale.so
cp ${BUILD_DIR}/extension/* /usr/pgsql-${PGVER}/share/extension/
chown postgres:postgres /usr/pgsql-${PGVER}/lib/vectorscale*
chown -R postgres:postgres /usr/pgsql-${PGVER}/share/extension/vectorscale*
echo "✅ Файлы pgvectorscale скопированы"

echo "===> Проверка установки"
ls -la /usr/pgsql-${PGVER}/lib/vectorscale*
ls -la /usr/pgsql-${PGVER}/share/extension/vectorscale*

echo ""
echo "============================================"
echo "✅ Копирование файлов для PostgreSQL ${PGVER} на реплике завершено"
echo "============================================"
echo "Рестарт Patroni будет выполнен на лидере через основной скрипт"
echo "============================================"

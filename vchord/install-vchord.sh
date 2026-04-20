#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Установка VectorChord из RPM для PostgreSQL
# Использование: ./install_vchord.sh <версия>
# Пример: ./install_vchord.sh 14
# ============================================

# Проверка аргумента
if [ $# -eq 0 ]; then
    echo "❌ Ошибка: укажите версию PostgreSQL"
    echo "Использование: $0 <версия>"
    echo "Пример: $0 14"
    exit 1
fi

PGVER=$1
RPM_DIR="/tmp/vchord_build/rpms/el8/pg${PGVER}"
SOCKET_DIR="/tmp"

echo "===> Установка pgvector (зависимость для VectorChord)"
dnf install -y pgvector_${PGVER}

echo "===> Установка VectorChord из RPM"
if [[ -d "${RPM_DIR}" ]]; then
    RPM_FILE=$(ls ${RPM_DIR}/vchord_${PGVER}-*.rpm 2>/dev/null | head -1)
    if [[ -f "${RPM_FILE}" ]]; then
        dnf localinstall -y "${RPM_FILE}"
        echo "✅ RPM установлен: ${RPM_FILE}"
    else
        echo "❌ RPM файл не найден в ${RPM_DIR}"
        exit 1
    fi
else
    echo "❌ Директория ${RPM_DIR} не найдена"
    exit 1
fi

echo "===> Добавление vchord в shared_preload_libraries"
PG_CONF="/var/lib/pgsql/${PGVER}/data/postgresql.conf"

if grep -q "shared_preload_libraries" "${PG_CONF}"; then
    if ! grep -q "vchord" "${PG_CONF}"; then
        sed -i "s/shared_preload_libraries = '\(.*\)'/shared_preload_libraries = '\1,vchord'/" "${PG_CONF}"
        echo "✅ vchord добавлен в shared_preload_libraries"
    else
        echo "⚠️ vchord уже есть в shared_preload_libraries"
    fi
else
    echo "shared_preload_libraries = 'vchord'" >> "${PG_CONF}"
    echo "✅ shared_preload_libraries создан с vchord"
fi

echo "===> Перезапуск PostgreSQL"
systemctl restart postgresql-${PGVER}

echo "===> Ожидание запуска PostgreSQL"
sleep 5

echo "===> Создание расширения в базе данных postgres"
sudo -u postgres psql -d postgres -h ${SOCKET_DIR} << EOF
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS vchord CASCADE;
EOF

echo ""
echo "============================================"
echo "✅ Установка VectorChord для PostgreSQL ${PGVER} завершена"
echo "============================================"

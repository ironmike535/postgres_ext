#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Установка pgvector и pgvectorscale из RPM для PostgreSQL
# Использование: ./install_rpm.sh <версия>
# Пример: ./install_rpm.sh 14
# ============================================

# Проверка аргумента
if [ $# -eq 0 ]; then
    echo "❌ Ошибка: укажите версию PostgreSQL"
    echo "Использование: $0 <версия>"
    echo "Пример: $0 14"
    exit 1
fi

PGVER=$1
RPM_DIR="/tmp/pgvectorscale_build/rpms/el8/pg${PGVER}"
SOCKET_DIR="/tmp"

echo "===> Установка pgvector (из репозитория)"
dnf install -y pgvector_${PGVER}

echo "===> Установка pgvectorscale из RPM"
if [[ -d "${RPM_DIR}" ]]; then
    RPM_FILE=$(ls ${RPM_DIR}/pgvectorscale_${PGVER}-*.rpm 2>/dev/null | head -1)
    if [[ -f "${RPM_FILE}" ]]; then
        dnf localinstall -y "${RPM_FILE}"
        echo "✅ RPM установлен: ${RPM_FILE}"
        
        # Создание символической ссылки
        cd /usr/pgsql-${PGVER}/lib/
        ln -sf vectorscale-*.so vectorscale.so
        echo "✅ Символическая ссылка создана"
    else
        echo "❌ RPM файл не найден в ${RPM_DIR}"
        exit 1
    fi
else
    echo "❌ Директория ${RPM_DIR} не найдена"
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
SELECT version();
SHOW shared_preload_libraries;
\dx
EOF

echo "===> Создание расширений в базе данных postgres"
sudo -u postgres psql -d postgres -h ${SOCKET_DIR} << EOF
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS vectorscale CASCADE;
SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'vectorscale');
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

#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Установка VectorChord из официального ZIP-архива
# Использование: ./install_vchord.sh <версия_PostgreSQL>
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
VCHORD_VERSION="1.1.1"
BASE_URL="https://github.com/tensorchord/VectorChord/releases/download/${VCHORD_VERSION}"
ZIP_FILE="postgresql-${PGVER}-vchord_${VCHORD_VERSION}_x86_64-linux-gnu.zip"
TEMP_DIR="/tmp/vchord_${PGVER}"

echo "===> Установка VectorChord ${VCHORD_VERSION} для PostgreSQL ${PGVER}"

# 1. Создание временной директории
echo "===> Создание временной директории ${TEMP_DIR}"
mkdir -p "${TEMP_DIR}"
cd "${TEMP_DIR}"

# 2. Скачивание архива
echo "===> Скачивание ${ZIP_FILE}"
curl -L -o "${ZIP_FILE}" "${BASE_URL}/${ZIP_FILE}"
if [[ $? -ne 0 ]]; then
    echo "❌ Ошибка: не удалось скачать файл"
    exit 1
fi

# 3. Распаковка
echo "===> Распаковка архива"
unzip -q "${ZIP_FILE}"

# 4. Проверка структуры распакованных файлов
echo "===> Проверка распакованных файлов"
ls -la

# 5. Копирование библиотеки
echo "===> Копирование файлов в /usr/pgsql-${PGVER}"
if [[ -f "pkglibdir/vchord.so" ]]; then
    cp pkglibdir/vchord.so "/usr/pgsql-${PGVER}/lib/"
    chown postgres:postgres "/usr/pgsql-${PGVER}/lib/vchord.so"
    echo "✅ Библиотека скопирована"
else
    echo "❌ Ошибка: pkglibdir/vchord.so не найден"
    exit 1
fi

# 6. Копирование файлов расширения
if [[ -d "sharedir/extension" ]]; then
    cp sharedir/extension/* "/usr/pgsql-${PGVER}/share/extension/"
    chown postgres:postgres "/usr/pgsql-${PGVER}/share/extension/vchord"*
    echo "✅ Файлы расширения скопированы"
else
    echo "❌ Ошибка: sharedir/extension не найден"
    exit 1
fi

echo "✅ Файлы VectorChord скопированы"

# 7. Добавление в shared_preload_libraries
echo "===> Добавление vchord.so в shared_preload_libraries"
PG_CONF="/var/lib/pgsql/${PGVER}/data/postgresql.conf"

if grep -q "shared_preload_libraries" "${PG_CONF}"; then
    if ! grep -q "vchord" "${PG_CONF}"; then
        sed -i "s/shared_preload_libraries = '\(.*\)'/shared_preload_libraries = '\1,vchord.so'/" "${PG_CONF}"
        echo "✅ vchord.so добавлен"
    else
        echo "⚠️ vchord.so уже есть"
    fi
else
    echo "shared_preload_libraries = 'vchord.so'" >> "${PG_CONF}"
    echo "✅ shared_preload_libraries создан"
fi

# 8. Перезапуск PostgreSQL
echo "===> Перезапуск PostgreSQL ${PGVER}"
systemctl restart postgresql-${PGVER}
sleep 5

# 9. Создание расширения
echo "===> Создание расширения vchord"
sudo -u postgres psql -h /tmp -d postgres << EOF
CREATE EXTENSION IF NOT EXISTS vchord CASCADE;
SELECT extname, extversion FROM pg_extension WHERE extname = 'vchord';
EOF

# 10. Очистка
echo "===> Очистка временных файлов"
cd /
rm -rf "${TEMP_DIR}"

echo ""
echo "============================================"
echo "✅ Установка VectorChord для PostgreSQL ${PGVER} завершена"
echo "============================================"

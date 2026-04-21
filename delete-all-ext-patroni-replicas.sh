#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Полное удаление векторных расширений на репликах Patroni
# Использование: ./delete-all-ext-patroni-replicas.sh <версия>
# Пример: ./delete-all-ext-patroni-replicas.sh 14
# ============================================

# Проверка аргумента
if [ $# -eq 0 ]; then
    echo "❌ Ошибка: укажите версию PostgreSQL"
    echo "Использование: $0 <версия>"
    echo "Пример: $0 14"
    exit 1
fi

PGVER=$1
LIB_DIR="/usr/pgsql-${PGVER}/lib"
EXTENSION_DIR="/usr/pgsql-${PGVER}/share/extension"

echo "============================================"
echo "Полное удаление векторных расширений на репликах Patroni для PostgreSQL ${PGVER}"
echo "============================================"

# 1. Удаление RPM пакетов
echo ""
echo "===> 1. Удаление RPM пакетов"
dnf remove -y pgvector_${PGVER} pgvectorscale_${PGVER} vchord_${PGVER} 2>/dev/null || echo "Пакеты не найдены или уже удалены"
echo "✅ RPM пакеты удалены"

# 2. Проверка удаления файлов
echo ""
echo "===> 2. Проверка удаления файлов"

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
echo "✅ Полное удаление векторных расширений на реплике Patroni для PostgreSQL ${PGVER} завершено"
echo "============================================"
echo "ВНИМАНИЕ: Расширения удалены только на реплике. На лидере удаление нужно выполнить отдельно."
echo "============================================"

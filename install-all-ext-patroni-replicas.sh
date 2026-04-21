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

# 4. Проверка установки файлов
echo ""
echo "===> 4. Проверка установки файлов"
echo "Проверка /usr/pgsql-${PGVER}/lib/:"
ls -la /usr/pgsql-${PGVER}/lib/vector* 2>/dev/null || echo "⚠️ Файлы vector не найдены"
ls -la /usr/pgsql-${PGVER}/lib/vectorscale* 2>/dev/null || echo "⚠️ Файлы vectorscale не найдены"
ls -la /usr/pgsql-${PGVER}/lib/vchord* 2>/dev/null || echo "⚠️ Файлы vchord не найдены"

echo ""
echo "Проверка /usr/pgsql-${PGVER}/share/extension/:"
ls -la /usr/pgsql-${PGVER}/share/extension/vector* 2>/dev/null || echo "⚠️ Файлы vector extension не найдены"
ls -la /usr/pgsql-${PGVER}/share/extension/vectorscale* 2>/dev/null || echo "⚠️ Файлы vectorscale extension не найдены"
ls -la /usr/pgsql-${PGVER}/share/extension/vchord* 2>/dev/null || echo "⚠️ Файлы vchord extension не найдены"

echo ""
echo "============================================"
echo "✅ Установка векторных расширений на реплике Patroni для PostgreSQL ${PGVER} завершена"
echo "============================================"
echo "ВНИМАНИЕ: Рестарт Patroni будет выполнен на лидере через основной скрипт"
echo "============================================"

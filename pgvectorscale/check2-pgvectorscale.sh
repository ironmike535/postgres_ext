#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Альтернативный чекер для pgvectorscale
# ============================================

echo "============================================"
echo "Проверка pgvectorscale (DiskANN)"
echo "============================================"

echo ""
echo "===> 1. Проверка файлов расширения"
if [[ -f "/usr/pgsql-14/lib/vectorscale.so" ]]; then
    echo "✅ vectorscale.so найден"
    ls -la /usr/pgsql-14/lib/vectorscale*
else
    echo "❌ vectorscale.so не найден"
fi

if [[ -f "/usr/pgsql-14/share/extension/vectorscale.control" ]]; then
    echo "✅ vectorscale.control найден"
    cat /usr/pgsql-14/share/extension/vectorscale.control | grep default_version
else
    echo "❌ vectorscale.control не найден"
fi

echo ""
echo "===> 2. Проверка shared_preload_libraries"
sudo -u postgres psql -h /tmp -d postgres -c "SHOW shared_preload_libraries;" | grep -q "vectorscale" && echo "✅ vectorscale загружен" || echo "❌ vectorscale НЕ загружен"

echo ""
echo "===> 3. Проверка расширений в БД"
sudo -u postgres psql -h /tmp -d postgres << EOF
SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'vectorscale');
EOF

echo ""
echo "===> 4. Проверка типа vector"
sudo -u postgres psql -h /tmp -d postgres -c "SELECT typname FROM pg_type WHERE typname = 'vector';" | grep -q "vector" && echo "✅ Тип vector существует" || echo "❌ Тип vector не найден"

echo ""
echo "===> 5. Проверка метода доступа diskann"
sudo -u postgres psql -h /tmp -d postgres -c "SELECT amname FROM pg_am WHERE amname = 'diskann';" | grep -q "diskann" && echo "✅ Метод diskann доступен" || echo "❌ Метод diskann НЕ доступен"

echo ""
echo "===> 6. Создание тестовой таблицы и индекса"
sudo -u postgres psql -h /tmp -d postgres << EOF
DROP TABLE IF EXISTS test_diskann CASCADE;
CREATE TABLE test_diskann (id SERIAL PRIMARY KEY, embedding vector(3));
INSERT INTO test_diskann (embedding) VALUES ('[1,2,3]'), ('[4,5,6]'), ('[7,8,9]'), ('[1.5,2.5,3.5]');
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_diskann_test ON test_diskann USING diskann (embedding vector_cosine_ops);
SELECT COUNT(*) as rows_indexed FROM test_diskann;
EOF

echo ""
echo "===> 7. Поиск ближайших соседей"
sudo -u postgres psql -h /tmp -d postgres << EOF
SELECT id, embedding, embedding <=> '[1,2,3]' as cosine_distance
FROM test_diskann 
ORDER BY embedding <=> '[1,2,3]' 
LIMIT 5;
EOF

echo ""
echo "============================================"
echo "✅ Проверка pgvectorscale завершена"
echo "============================================"

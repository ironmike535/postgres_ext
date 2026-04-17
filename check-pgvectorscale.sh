#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Проверка установки pgvector и pgvectorscale
# ============================================

echo "============================================"
echo "Проверка pgvector и pgvectorscale"
echo "============================================"

echo ""
echo "===> 1. Проверка shared_preload_libraries"
sudo -u postgres psql -h /tmp -d postgres -c "SHOW shared_preload_libraries;"

echo ""
echo "===> 2. Проверка установленных расширений"
sudo -u postgres psql -h /tmp -d postgres << EOF
SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'vectorscale');
EOF

echo ""
echo "===> 3. Создание тестовой таблицы"
sudo -u postgres psql -h /tmp -d postgres << EOF
DROP TABLE IF EXISTS test_vec_small CASCADE;
CREATE TABLE test_vec_small (
    id SERIAL PRIMARY KEY,
    embedding VECTOR(3)
);
EOF

echo ""
echo "===> 4. Вставка тестовых данных"
sudo -u postgres psql -h /tmp -d postgres << EOF
INSERT INTO test_vec_small (embedding) VALUES 
    ('[1, 2, 3]'),
    ('[4, 5, 6]'),
    ('[7, 8, 9]'),
    ('[1.5, 2.5, 3.5]');
SELECT COUNT(*) AS rows_inserted FROM test_vec_small;
EOF

echo ""
echo "===> 5. Создание индекса DiskANN"
sudo -u postgres psql -h /tmp -d postgres -c "CREATE INDEX IF NOT EXISTS idx_vec_small ON test_vec_small USING diskann (embedding vector_cosine_ops);"

echo ""
echo "===> 6. Поиск ближайших соседей"
sudo -u postgres psql -h /tmp -d postgres << EOF
SELECT *, embedding <=> '[1, 2, 3]' as distance
FROM test_vec_small 
ORDER BY embedding <=> '[1, 2, 3]' 
LIMIT 5;
EOF

echo ""
echo "============================================"
echo "✅ Проверка завершена"
echo "============================================"

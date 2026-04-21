#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Проверка установки VectorChord (vchord)
# ============================================

echo "============================================"
echo "Проверка VectorChord (vchord) и pgvector"
echo "============================================"

echo ""
echo "===> 1. Проверка shared_preload_libraries"
sudo -u postgres psql -h /tmp -d postgres -c "SHOW shared_preload_libraries;"

echo ""
echo "===> 2. Проверка установленных расширений"
sudo -u postgres psql -h /tmp -d postgres << EOF
SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'vchord');
EOF

echo ""
echo "===> 3. Создание тестовой таблицы"
sudo -u postgres psql -h /tmp -d postgres << EOF
DROP TABLE IF EXISTS test_vchord_small CASCADE;
CREATE TABLE test_vchord_small (
    id SERIAL PRIMARY KEY,
    embedding VECTOR(3)
);
EOF

echo ""
echo "===> 4. Вставка тестовых данных"
sudo -u postgres psql -h /tmp -d postgres << EOF
INSERT INTO test_vchord_small (embedding) VALUES 
    ('[1, 2, 3]'),
    ('[4, 5, 6]'),
    ('[7, 8, 9]'),
    ('[1.5, 2.5, 3.5]');
SELECT COUNT(*) AS rows_inserted FROM test_vchord_small;
EOF

echo ""
echo "===> 5. Создание индекса (используя метод vchordrq)"
sudo -u postgres psql -h /tmp -d postgres -c "CREATE INDEX IF NOT EXISTS idx_test_vchord ON test_vchord_small USING vchordrq (embedding vector_l2_ops);"

echo ""
echo "===> 6. Поиск ближайших соседей (по косинусному расстоянию)"
sudo -u postgres psql -h /tmp -d postgres << EOF
SELECT *, embedding <=> '[1, 2, 3]' as distance
FROM test_vchord_small 
ORDER BY embedding <=> '[1, 2, 3]' 
LIMIT 5;
EOF

echo ""
echo "============================================"
echo "✅ Проверка VectorChord завершена"
echo "============================================"

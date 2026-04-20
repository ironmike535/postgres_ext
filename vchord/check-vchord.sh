#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Проверка работы VectorChord
# ============================================

PGVER=14
SOCKET_DIR="/tmp"

echo "============================================"
echo "Проверка VectorChord для PostgreSQL ${PGVER}"
echo "============================================"

echo ""
echo "===> 1. Проверка расширений в БД"
sudo -u postgres psql -d postgres -h ${SOCKET_DIR} -c "SELECT extname, extversion FROM pg_extension WHERE extname IN ('vector', 'vchord');"

echo ""
echo "===> 2. Проверка shared_preload_libraries"
sudo -u postgres psql -d postgres -h ${SOCKET_DIR} -c "SHOW shared_preload_libraries;"

echo ""
echo "===> 3. Создание тестовой таблицы"
sudo -u postgres psql -d postgres -h ${SOCKET_DIR} << EOF
DROP TABLE IF EXISTS test_vchord CASCADE;
CREATE TABLE test_vchord (
    id SERIAL PRIMARY KEY,
    embedding vector(3)
);
INSERT INTO test_vchord (embedding) VALUES 
    ('[1, 2, 3]'),
    ('[4, 5, 6]'),
    ('[7, 8, 9]'),
    ('[1.5, 2.5, 3.5]');
SELECT COUNT(*) AS rows_inserted FROM test_vchord;
EOF

echo ""
echo "===> 4. Создание индекса (если поддерживается)"
sudo -u postgres psql -d postgres -h ${SOCKET_DIR} << EOF
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_test_vchord 
ON test_vchord USING vchordrq (embedding vector_l2_ops);
EOF

echo ""
echo "===> 5. Поиск ближайших соседей (cosine distance)"
sudo -u postgres psql -d postgres -h ${SOCKET_DIR} << EOF
SELECT id, embedding, embedding <=> '[1, 2, 3]' as distance
FROM test_vchord 
ORDER BY embedding <=> '[1, 2, 3]' 
LIMIT 5;
EOF

echo ""
echo "===> 6. Поиск ближайших соседей (Euclidean distance)"
sudo -u postgres psql -d postgres -h ${SOCKET_DIR} << EOF
SELECT id, embedding, embedding <-> '[1, 2, 3]' as euclidean_distance
FROM test_vchord 
ORDER BY embedding <-> '[1, 2, 3]' 
LIMIT 5;
EOF

echo ""
echo "============================================"
echo "✅ Проверка завершена"
echo "============================================"

#!/usr/bin/env bash
set -euo pipefail

PGVER=14
SOCKET_DIR="/tmp"
DB_NAME="postgres"

echo "============================================"
echo "Проверка vector, vectorscale и vchord"
echo "============================================"

# 1. Проверка shared_preload_libraries
echo ""
echo "===> 1. Проверка shared_preload_libraries"
sudo -u postgres psql -h ${SOCKET_DIR} -d ${DB_NAME} -c "SHOW shared_preload_libraries;"

# 2. Проверка установленных расширений
echo ""
echo "===> 2. Проверка установленных расширений"
sudo -u postgres psql -h ${SOCKET_DIR} -d ${DB_NAME} << EOF
SELECT extname, extversion
FROM pg_extension
WHERE extname IN ('vector', 'vectorscale', 'vchord');
EOF

# 3. Проверка типа vector и операторов
echo ""
echo "===> 3. Проверка типа vector и операторов"
sudo -u postgres psql -h ${SOCKET_DIR} -d ${DB_NAME} << EOF
SELECT typname FROM pg_type WHERE typname = 'vector';
SELECT '<=>'::text as cosine_operator;
EOF

# 4. Проверка diskann (vectorscale)
echo ""
echo "===> 4. Проверка метода diskann"
sudo -u postgres psql -h ${SOCKET_DIR} -d ${DB_NAME} -c "SELECT amname FROM pg_am WHERE amname = 'diskann';"

# 5. Проверка vchordrq (vchord)
echo ""
echo "===> 5. Проверка метода vchordrq"
sudo -u postgres psql -h ${SOCKET_DIR} -d ${DB_NAME} -c "SELECT amname FROM pg_am WHERE amname = 'vchordrq';"

# 6. Функциональный тест
echo ""
echo "===> 6. Функциональный тест"
sudo -u postgres psql -h ${SOCKET_DIR} -d ${DB_NAME} << EOF
DROP TABLE IF EXISTS test_vector CASCADE;
CREATE TABLE test_vector (id SERIAL PRIMARY KEY, embedding VECTOR(3));
INSERT INTO test_vector (embedding) VALUES ('[1,2,3]'), ('[4,5,6]'), ('[7,8,9]'), ('[1.5,2.5,3.5]');
SELECT id, embedding, embedding <=> '[1,2,3]' as distance FROM test_vector ORDER BY embedding <=> '[1,2,3]' LIMIT 5;
DROP TABLE IF EXISTS test_vector CASCADE;
EOF

echo ""
echo "✅ Проверка завершена"

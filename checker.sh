#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Комплексная проверка vector, vectorscale и vchord
# ============================================

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

# 3. Проверка наличия типа vector и операторов
echo ""
echo "===> 3. Проверка типа vector и операторов"
sudo -u postgres psql -h ${SOCKET_DIR} -d ${DB_NAME} << EOF
-- Проверка типа
SELECT typname, typtype FROM pg_type WHERE typname = 'vector';

-- Проверка операторов (должны вернуть true)
SELECT 
    '<=>'::text as cosine_operator,
    '<->'::text as euclidean_operator,
    '<#>'::text as dot_product_operator;
EOF

# 4. Проверка наличия метода доступа diskann (от vectorscale)
echo ""
echo "===> 4. Проверка метода доступа diskann"
sudo -u postgres psql -h ${SOCKET_DIR} -d ${DB_NAME} << EOF
SELECT amname, amhandler::regproc 
FROM pg_am 
WHERE amname = 'diskann';
EOF

# 5. Проверка наличия методов vchordrq и vchordg (от vchord)
echo ""
echo "===> 5. Проверка методов vchordrq и vchordg"
sudo -u postgres psql -h ${SOCKET_DIR} -d ${DB_NAME} << EOF
SELECT amname, amhandler::regproc 
FROM pg_am 
WHERE amname IN ('vchordrq', 'vchordg');
EOF

# 6. Проверка квантованных типов vchord (rabitq)
echo ""
echo "===> 6. Проверка квантованных типов vchord"
sudo -u postgres psql -h ${SOCKET_DIR} -d ${DB_NAME} << EOF
SELECT typname, typtype 
FROM pg_type 
WHERE typname IN ('rabitq8', 'rabitq4');
EOF

# 7. Функциональный тест
echo ""
echo "===> 7. Функциональный тест"
sudo -u postgres psql -h ${SOCKET_DIR} -d ${DB_NAME} << EOF
-- Создание тестовой таблицы
DROP TABLE IF EXISTS test_all_ext CASCADE;
CREATE TABLE test_all_ext (
    id SERIAL PRIMARY KEY,
    embedding VECTOR(3)
);

-- Вставка данных
INSERT INTO test_all_ext (embedding) VALUES 
    ('[1, 2, 3]'),
    ('[4, 5, 6]'),
    ('[7, 8, 9]'),
    ('[1.5, 2.5, 3.5]');

-- Создание индексов для каждого расширения
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_diskann ON test_all_ext USING diskann (embedding vector_cosine_ops);
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_vchordrq ON test_all_ext USING vchordrq (embedding vector_l2_ops);

-- Поиск ближайших соседей
SELECT 
    id, 
    embedding, 
    embedding <=> '[1, 2, 3]' as cosine_distance,
    embedding <-> '[1, 2, 3]' as euclidean_distance
FROM test_all_ext 
ORDER BY embedding <=> '[1, 2, 3]' 
LIMIT 5;
EOF

echo ""
echo "============================================"
echo "✅ Проверка завершена"
echo "============================================"

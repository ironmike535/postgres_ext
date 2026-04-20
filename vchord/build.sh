#!/usr/bin/env bash
set -euo pipefail

# Версии PostgreSQL для сборки
PG_VERSIONS=(14 15 16 17)

OUTPUT_DIR="/tmp/vchord_build"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

for PGVER in "${PG_VERSIONS[@]}"; do
    echo ""
    echo "============================================"
    echo "Сборка VectorChord для PostgreSQL ${PGVER}"
    echo "============================================"

    docker run --rm \
      -e PGVER="$PGVER" \
      -v "$OUTPUT_DIR:/out" \
      rockylinux:8 \
      bash -c '
        set -euo pipefail

        echo "===> Установка зависимостей"
        dnf install -y epel-release
        dnf config-manager --set-enabled powertools || true
        dnf install -y perl-IPC-Run
        dnf install -y gcc gcc-c++ clang git make curl openssl-devel
        dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm
        dnf module disable -y postgresql || true
        dnf install -y "postgresql${PGVER}-devel"

        echo "===> Установка Rust"
        curl --proto "=https" --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source /root/.cargo/env

        echo "===> Настройка компилятора"
        export CC=clang
        export CXX=clang++

        echo "===> Скачивание исходников"
        cd /tmp
        curl -fsSL https://github.com/tensorchord/VectorChord/archive/refs/tags/1.1.1.tar.gz | tar -xz
        cd VectorChord-1.1.1

        export PATH="/usr/pgsql-${PGVER}/bin:${PATH}"
        export PG_CONFIG="/usr/pgsql-${PGVER}/bin/pg_config"

        echo "===> Сборка через make"
        make build
        make install

        echo "===> Копирование артефактов"
        out="/out/rhel8/pg${PGVER}"
        mkdir -p "${out}/lib" "${out}/extension"
        cp /usr/pgsql-${PGVER}/lib/vchord.so "${out}/lib/"
        cp /usr/pgsql-${PGVER}/share/extension/vchord* "${out}/extension/"

        echo "✅ Готово для PostgreSQL ${PGVER}"
      '
done

echo ""
echo "============================================"
echo "✅ Сборка файлов завершена для версий: ${PG_VERSIONS[@]}"
echo "Файлы: ${OUTPUT_DIR}/rhel8/pg{14,15,16,17}/"
echo "============================================"

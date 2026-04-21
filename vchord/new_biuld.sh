#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Сборка VectorChord для Rocky Linux 8 или 9
# Выберите версию: 8 или 9
# ============================================

# Выберите версию Rocky Linux: 8 или 9
RHEL_VERSION=9

# Версии PostgreSQL для сборки
PG_VERSIONS=(14 15 16 17)

OUTPUT_DIR="/tmp/vchord_build_rhel${RHEL_VERSION}"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "============================================"
echo "Сборка VectorChord для Rocky Linux ${RHEL_VERSION}"
echo "Версии PostgreSQL: ${PG_VERSIONS[@]}"
echo "============================================"

for PGVER in "${PG_VERSIONS[@]}"; do
    echo ""
    echo "============================================"
    echo "Сборка VectorChord для PostgreSQL ${PGVER} (RHEL${RHEL_VERSION})"
    echo "============================================"

    docker run --rm \
      -e PGVER="$PGVER" \
      -e RHEL_VERSION="$RHEL_VERSION" \
      -v "$OUTPUT_DIR:/out" \
      "rockylinux:${RHEL_VERSION}" \
      bash -c '
        set -euo pipefail

        rhel_version=$RHEL_VERSION
        pgver=$PGVER

        echo "===> Установка зависимостей"

        if [[ "${rhel_version}" == "8" ]]; then
            dnf install -y epel-release
            dnf config-manager --set-enabled powertools || true
            dnf install -y perl-IPC-Run
            dnf install -y gcc gcc-c++ clang git make curl openssl-devel
        elif [[ "${rhel_version}" == "9" ]]; then
            dnf install -y epel-release
            dnf config-manager --set-enabled crb || true
            dnf install -y perl-IPC-Run
            dnf install -y --allowerasing gcc gcc-c++ clang git make curl openssl-devel
        fi

        dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-${rhel_version}-x86_64/pgdg-redhat-repo-latest.noarch.rpm
        dnf module disable -y postgresql || true
        dnf install -y "postgresql${pgver}-devel"

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

        export PATH="/usr/pgsql-${pgver}/bin:${PATH}"
        export PG_CONFIG="/usr/pgsql-${pgver}/bin/pg_config"

        echo "===> Сборка через make"
        make build
        make install

        echo "===> Копирование артефактов"
        out="/out/rhel${rhel_version}/pg${pgver}"
        mkdir -p "${out}/lib" "${out}/extension"
        cp /usr/pgsql-${pgver}/lib/vchord.so "${out}/lib/"
        cp /usr/pgsql-${pgver}/share/extension/vchord* "${out}/extension/"

        echo "✅ Готово для PostgreSQL ${pgver} (RHEL${rhel_version})"
      '
done

echo ""
echo "============================================"
echo "✅ Сборка файлов завершена"
echo "Версии PostgreSQL: ${PG_VERSIONS[@]}"
echo "Rocky Linux версия: ${RHEL_VERSION}"
echo "Файлы: ${OUTPUT_DIR}/rhel${RHEL_VERSION}/pg{14,15,16,17}/"
echo "============================================"
